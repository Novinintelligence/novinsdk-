import Foundation

public struct ReasoningConfig: Codable {
    public var enableFearChain: Bool
    public var enableSymbolicPlanner: Bool
    public var enableAffordancePlanner: Bool
    public var enableEnvironmentalMirror: Bool

    public init(enableFearChain: Bool,
                enableSymbolicPlanner: Bool,
                enableAffordancePlanner: Bool,
                enableEnvironmentalMirror: Bool) {
        self.enableFearChain = enableFearChain
        self.enableSymbolicPlanner = enableSymbolicPlanner
        self.enableAffordancePlanner = enableAffordancePlanner
        self.enableEnvironmentalMirror = enableEnvironmentalMirror
    }

    public static let `default` = ReasoningConfig(
        enableFearChain: false,
        enableSymbolicPlanner: false,
        enableAffordancePlanner: false,
        enableEnvironmentalMirror: false
    )
}
