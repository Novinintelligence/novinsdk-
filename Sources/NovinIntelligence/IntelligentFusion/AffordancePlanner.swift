import Foundation

/// Training-free affordance-based planner producing practical action suggestions
public final class AffordancePlanner {
    public init() {}

    /// Suggest a simple sequence of actions from features/metadata
    /// - Note: deterministic rules; no learning. Ultra-lightweight.
    public func suggest(features: [String: Double], metadata: [String: Any]?) -> Plan {
        var steps: [Action] = []

        let zoneRisk = features["zone_risk"] ?? 0.5
        let isGlass = (features["event_glassbreak"] ?? 0.0) > 0.5
        let isMotion = (features["event_motion"] ?? 0.0) > 0.5
        let confidence = features["event_confidence"] ?? 0.5
        let homeMode = (metadata?["home_mode"] as? String)?.lowercased() ?? "unknown"

        // Basic affordance-like decisions
        if isGlass {
            // Strong indicator: secure + verify + notify
            steps.append(Action(name: "secure_perimeter"))
            steps.append(Action(name: "request_verification"))
            steps.append(Action(name: "notify_owner"))
        } else if isMotion {
            if zoneRisk > 0.6 || homeMode == "away" {
                steps.append(Action(name: "focus_camera"))
                steps.append(Action(name: "record_clip"))
                steps.append(Action(name: "notify_owner"))
            } else {
                if confidence > 0.7 { steps.append(Action(name: "record_clip")) }
            }
        }

        return Plan(steps: steps, estimatedCost: Double(steps.count))
    }
}
