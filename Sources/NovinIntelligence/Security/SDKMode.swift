import Foundation

/// SDK operational modes for graceful degradation
@available(iOS 15.0, macOS 12.0, *)
public enum SDKMode: String, Codable {
    case full          // All features enabled
    case degraded      // User patterns disabled, core AI active
    case minimal       // Only rule-based reasoning, no fusion
    case emergency     // Always return standard threat level
    
    /// Get mode description
    public var description: String {
        switch self {
        case .full:
            return "Full mode: All AI features active"
        case .degraded:
            return "Degraded mode: Core AI active, pattern learning disabled"
        case .minimal:
            return "Minimal mode: Rule-based reasoning only"
        case .emergency:
            return "Emergency mode: Safe fallback responses"
        }
    }
    
    /// Check if feature is available in this mode
    public func isFeatureAvailable(_ feature: SDKFeature) -> Bool {
        switch self {
        case .full:
            return true
        case .degraded:
            return feature != .userPatternLearning && feature != .telemetry
        case .minimal:
            return feature == .ruleBasedReasoning
        case .emergency:
            return false
        }
    }
}

/// SDK features that can be enabled/disabled
@available(iOS 15.0, macOS 12.0, *)
public enum SDKFeature {
    case ruleBasedReasoning
    case bayesianFusion
    case mentalModelSimulation
    case temporalDampening
    case userPatternLearning
    case telemetry
    case auditTrail
}




