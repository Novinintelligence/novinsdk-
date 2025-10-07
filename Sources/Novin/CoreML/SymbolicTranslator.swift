import Foundation

/// Maps extracted features into symbolic predicates and affordances (training-free)
public final class SymbolicTranslator {
    public init() {}

    /// Deterministic mapping from numeric features to predicates
    public func translate(features: [String: Double]) -> [Predicate] {
        return translate(features: features, request: nil)
    }

    /// Deterministic mapping from numeric features (+request) to canonical predicates used by mirror
    public func translate(features: [String: Double], request: [String: Any]?) -> [Predicate] {
        var preds: [Predicate] = []
        // Always begin at observe stage for planning
        preds.append(Predicate("stage_observe"))

        // Event-based detections
        if (features["event_motion"] ?? 0.0) > 0.7 { preds.append(Predicate("motion_detected")) }
        if (features["event_sound"] ?? 0.0) > 0.7 { preds.append(Predicate("sound_detected")) }
        if (features["event_glassbreak"] ?? 0.0) > 0.5 { preds.append(Predicate("glassbreak_detected")) }

        // Sensor reliability / confidence
        if (features["event_confidence"] ?? 0.0) > 0.7 { preds.append(Predicate("high_confidence")) }

        // Temporal
        if (features["hour_cos"] ?? 0.0) < -0.5 { preds.append(Predicate("night_time")) }
        if let hm = ((request?["home_mode"] as? String) ?? ((request?["metadata"] as? [String: Any])?["home_mode"] as? String))?.lowercased(), hm == "away" {
            preds.append(Predicate("away_mode_active"))
        }

        // Spatial risk
        if (features["zone_risk"] ?? 0.0) > 0.7 {
            preds.append(Predicate("high_risk_zone"))
            preds.append(Predicate("perimeter"))
        }
        return preds
    }
}
