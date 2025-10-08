import Foundation

public struct Plan: Codable, Hashable {
    public let steps: [Action]
    public let estimatedCost: Double
    public init(steps: [Action] = [], estimatedCost: Double = 0.0) {
        self.steps = steps
        self.estimatedCost = estimatedCost
    }
}

public struct ExecutionReport: Codable {
    public let status: String
    public let metrics: [String: Double]
    public let reasoningTrace: String?
    public init(status: String, metrics: [String: Double] = [:], reasoningTrace: String? = nil) {
        self.status = status
        self.metrics = metrics
        self.reasoningTrace = reasoningTrace
    }
}
