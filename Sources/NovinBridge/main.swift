import Foundation
import NIO
import NIOHTTP1
import NovinIntelligence

@main
struct NovinBridge {
    static func main() async {
        do {
            try await NovinIntelligence.shared.initialize()

            let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
            defer { try? group.syncShutdownGracefully() }

            let host = ProcessInfo.processInfo.environment["NOVIN_BIND_HOST"] ?? "127.0.0.1"
            let port: Int = Int(ProcessInfo.processInfo.environment["NOVIN_BIND_PORT"] ?? "8088") ?? 8088

            let bootstrap = ServerBootstrap(group: group)
                .serverChannelOption(ChannelOptions.backlog, value: 256)
                .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .childChannelInitializer { channel in
                    channel.pipeline.configureHTTPServerPipeline().flatMap {
                        channel.pipeline.addHandler(HTTPHandler())
                    }
                }
                .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
                .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

            let channel = try bootstrap.bind(host: host, port: port).wait()
            print("✅ novin-bridge listening on http://\(host):\(port)")
            try channel.closeFuture.wait()
        } catch {
            fputs("novin-bridge failed: \(error)\n", stderr)
            exit(1)
        }
    }
}

final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private var buffer: ByteBuffer!
    private var pendingBody = Data()
    private var method: HTTPMethod = .GET
    private var uri: String = "/"

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)
        switch part {
        case .head(let head):
            self.method = head.method
            self.uri = head.uri
            self.pendingBody.removeAll(keepingCapacity: false)
        case .body(var body):
            if let bytes = body.readBytes(length: body.readableBytes) {
                pendingBody.append(contentsOf: bytes)
            }
        case .end:
            handleRequest(context: context)
        }
    }

    private func handleRequest(context: ChannelHandlerContext) {
        switch (method, uri) {
        case (.GET, "/health"):
            respond(context: context, status: .ok, json: ["status": "ok"])
        case (.POST, "/assess"):
            guard let json = String(data: pendingBody, encoding: .utf8), !json.isEmpty else {
                respond(context: context, status: .badRequest, json: ["error": "empty body"]) ; return
            }
            Task {
                do {
                    let result = try await NovinIntelligence.shared.assess(requestJson: json)
                    var out: [String: Any] = [
                        "threat": result.threatLevel.rawValue,
                        "confidence": result.confidence,
                        "processing_ms": result.processingTimeMs,
                        "request_id": result.requestId as Any,
                        "timestamp": result.timestamp as Any
                    ]
                    if let s = result.summary { out["summary"] = s }
                    if let dr = result.detailedReasoning, !dr.isEmpty { out["reasoning"] = dr }
                    else if !result.reasoning.isEmpty { out["reasoning"] = result.reasoning }
                    if let rec = result.recommendation { out["recommendation"] = rec }
                    if let ctx = result.context { out["context"] = ctx }
                    self.respond(context: context, status: .ok, json: out)
                } catch {
                    self.respond(context: context, status: .internalServerError, json: ["error": String(describing: error)])
                }
            }
        default:
            respond(context: context, status: .notFound, json: ["error": "not found"])            
        }
    }

    private func respond(context: ChannelHandlerContext, status: HTTPResponseStatus, json: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "application/json")
            headers.add(name: "Content-Length", value: String(data.count))
            let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: status, headers: headers)
            context.write(self.wrapOutboundOut(.head(head)), promise: nil)
            var body = context.channel.allocator.buffer(capacity: data.count)
            body.writeBytes(data)
            context.write(self.wrapOutboundOut(.body(.byteBuffer(body))), promise: nil)
            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
        } catch {
            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "application/json")
            let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .internalServerError, headers: headers)
            context.write(self.wrapOutboundOut(.head(head)), promise: nil)
            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
        }
    }
}
