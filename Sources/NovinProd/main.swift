import Foundation
import NovinIntelligence

@main
struct NovinProd {
    static func main() async {
        var verbose = false
        var filePath: String? = nil
        var args = Array(CommandLine.arguments.dropFirst())
        while let a = args.first {
            args.removeFirst()
            switch a {
            case "--verbose", "-v": verbose = true
            case "--file", "-f": if let p = args.first { filePath = p; args.removeFirst() }
            default: break
            }
        }

        do {
            try await NovinIntelligence.shared.initialize()
            // Read events from file or stdin
            if let file = filePath {
                let data = try String(contentsOfFile: file, encoding: .utf8)
                for line in data.split(whereSeparator: { $0.isNewline }) {
                    try await process(String(line), verbose: verbose)
                }
            } else {
                // stdin loop
                while let line = readLine() {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty { continue }
                    try await process(trimmed, verbose: verbose)
                }
            }
        } catch {
            fputs("{\"error\":\"\(error)\"}\n", stderr)
            exit(1)
        }
    }

    static func process(_ json: String, verbose: Bool) async throws {
        do {
            let result = try await NovinIntelligence.shared.assess(requestJson: json)
            var out: [String: Any] = [
                "threat": result.threatLevel.rawValue,
                "confidence": result.confidence,
                "processing_ms": result.processingTimeMs,
                "request_id": result.requestId,
                "timestamp": result.timestamp
            ]
            if let s = result.summary { out["summary"] = s }
            if verbose {
                if let r = result.detailedReasoning, !r.isEmpty { out["reasoning"] = r }
                else if !result.reasoning.isEmpty { out["reasoning"] = result.reasoning }
                if let rec = result.recommendation { out["recommendation"] = rec }
                if let ctx = result.context { out["context"] = ctx }
            }
            let data = try JSONSerialization.data(withJSONObject: out, options: [])
            if let line = String(data: data, encoding: .utf8) { print(line) }
        } catch {
            var err: [String: Any] = ["error": String(describing: error)]
            // echo input for debugging
            err["input"] = json
            let data = try JSONSerialization.data(withJSONObject: err, options: [])
            if let line = String(data: data, encoding: .utf8) { fputs(line+"\n", stderr) }
        }
    }
}
