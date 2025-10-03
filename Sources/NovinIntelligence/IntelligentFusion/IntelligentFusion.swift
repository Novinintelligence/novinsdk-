import Foundation

@available(iOS 15.0, macOS 12.0, *)
struct IntelligentFusion {
    // MARK: - Core types
    struct EvidenceFactor {
        let name: String
        let present: Double
        let threatLikelihood: Double
        let noThreatLikelihood: Double
        let weight: Double
    }

    struct FusionResult {
        let finalScore: Double
        let confidence: Double
        let explanation: [EvidenceFactor]
        let bayesianContribution: Double
        let ruleContribution: Double
    }

    private struct Likelihood {
        let threat: Double
        let noThreat: Double
        let weight: Double
    }

    // MARK: - Config
    private let baseThreatProbability: Double = 0.05
    private let likelihoods: [String: Likelihood] = [
        // Temporal
        "night": .init(threat: 0.80, noThreat: 0.30, weight: 1.5),
        "weekend": .init(threat: 0.60, noThreat: 0.40, weight: 1.2),
        "recent_event": .init(threat: 0.70, noThreat: 0.20, weight: 1.3),
        "unusual_hour": .init(threat: 0.75, noThreat: 0.25, weight: 1.4),
        // Spatial
        "high_crime": .init(threat: 0.90, noThreat: 0.10, weight: 2.0),
        "crime_trend": .init(threat: 0.85, noThreat: 0.15, weight: 1.8),
        // Events
        "motion": .init(threat: 0.60, noThreat: 0.40, weight: 1.0),
        "door": .init(threat: 0.80, noThreat: 0.20, weight: 1.6),
        "window": .init(threat: 0.85, noThreat: 0.15, weight: 1.7),
        "sound": .init(threat: 0.50, noThreat: 0.50, weight: 0.8),
        "unknown_face": .init(threat: 0.90, noThreat: 0.05, weight: 2.2),
        "glass_break": .init(threat: 0.95, noThreat: 0.05, weight: 2.5),
        "pet": .init(threat: 0.10, noThreat: 0.90, weight: 0.5),
        // Behavioral
        "away_mode": .init(threat: 0.90, noThreat: 0.10, weight: 2.0),
        "high_risk_user": .init(threat: 0.80, noThreat: 0.20, weight: 1.5),
        "unusual_activity": .init(threat: 0.70, noThreat: 0.30, weight: 1.3),
        // Sensor reliability
        "high_confidence": .init(threat: 0.90, noThreat: 0.40, weight: 1.2),
        "multiple_sensors": .init(threat: 0.85, noThreat: 0.30, weight: 1.4)
    ]

    // MARK: - Public API
    func fuse(features: [String: Double], rules: ReasoningSwift.Result, request: [String: Any]) -> FusionResult {
        let evidence = extractEvidence(from: features, request: request)
        let bayes = bayesianProbability(evidence)
        let fused = fuseBayesAndRules(bayes: bayes, rules: rules, evidence: evidence)
        return FusionResult(
            finalScore: fused.score,
            confidence: fused.confidence,
            explanation: evidence,
            bayesianContribution: bayes.probability,
            ruleContribution: rules.riskScore
        )
    }

    // MARK: - Evidence extraction
    private func extractEvidence(from features: [String: Double], request: [String: Any]) -> [EvidenceFactor] {
        var out: [EvidenceFactor] = []

        func add(_ key: String, name: String, present: Double = 1.0) {
            guard let lik = likelihoods[key], present > 0 else { return }
            out.append(EvidenceFactor(name: name, present: min(max(present, 0), 1), threatLikelihood: lik.threat, noThreatLikelihood: lik.noThreat, weight: lik.weight))
        }

        // Temporal
        if (features["hour_cos"] ?? 0.0) < -0.5 { add("night", name: "night_time") }
        if (features["is_weekend"] ?? 0.0) > 0.5 { add("weekend", name: "weekend_activity", present: features["is_weekend"] ?? 1.0) }
        if (features["hours_since_last_event"] ?? 1.0) < 0.1 { add("recent_event", name: "recent_event") }

        // Spatial
        let crime24h = features["crime_rate_24h"] ?? 0.0
        // Continuous scaling: 0 at 0.2, saturate to 1.0 at 1.0
        if crime24h > 0.2 {
            let strength = min(1.0, max(0.0, (crime24h - 0.2) / 0.8))
            add("high_crime", name: "high_crime_area", present: strength)
        }
        let crime7d = features["crime_rate_7d"] ?? 0.0
        if crime7d > crime24h { add("crime_trend", name: "rising_crime", present: 0.8) }

        // Events
        let evConf = features["event_confidence"] ?? 0.5
        let types = ["motion","door","window","sound","face","glassbreak","pet"]
        for t in types {
            if (features["event_\(t)"] ?? 0.0) > 0.5 {
                if t == "face" {
                    // Treat as unknown face only when trust is low
                    let trust = features["user_trust_level"] ?? 0.5
                    if trust < 0.5 {
                        add("unknown_face", name: "face_detected", present: min(1.0, (features["event_face"] ?? 1.0) * evConf))
                    }
                    // else: likely known face → no threat evidence added
                } else {
                    let key = (t == "glassbreak" ? "glass_break" : t)
                    add(key, name: "\(t)_detected", present: min(1.0, (features["event_\(t)"] ?? 1.0) * evConf))
                }
            }
        }

        // Behavioral
        if (request["home_mode"] as? String) == "away" { add("away_mode", name: "away_mode_active") }
        if (features["user_risk_score"] ?? 0.0) > 0.6 { add("high_risk_user", name: "high_risk_profile", present: features["user_risk_score"] ?? 1.0) }
        if (features["activity_consistency"] ?? 0.5) < 0.3 { add("unusual_activity", name: "unusual_pattern", present: 1.0 - (features["activity_consistency"] ?? 0.5)) }

        // Sensor reliability
        if evConf > 0.7 { add("high_confidence", name: "high_confidence", present: evConf) }
        if (features["sensor_count"] ?? 0.0) > 0.5 { add("multiple_sensors", name: "multi_sensor", present: features["sensor_count"] ?? 1.0) }

        return out
    }

    // MARK: - Bayesian math
    private func bayesianProbability(_ evidence: [EvidenceFactor]) -> (probability: Double, logOdds: Double) {
        // Numerically stable log-odds update
        let eps = 1e-9
        var logOdds = log((baseThreatProbability + eps) / max(eps, 1.0 - baseThreatProbability))
        for e in evidence where e.present > 0.1 {
            let s = min(max(e.present, 0), 1)
            // Likelihood ratio for this factor
            let lr = max(eps, e.threatLikelihood / max(eps, e.noThreatLikelihood))
            // Scale contribution by evidence strength and factor weight
            logOdds += log(lr) * (e.weight * s)
        }
        // Convert back to probability
        let prob = 1.0 / (1.0 + exp(-logOdds))
        return (probability: prob, logOdds: logOdds / log(2.0))
    }

    // MARK: - Fusion
    private func fuseBayesAndRules(bayes: (probability: Double, logOdds: Double), rules: ReasoningSwift.Result, evidence: [EvidenceFactor]) -> (score: Double, confidence: Double) {
        let bayesScore = bayes.probability
        let ruleScore = rules.riskScore

        // Evidence diversity heuristic
        let diversity = evidence.map { $0.weight }.reduce(0, +) / max(1.0, Double(evidence.count))
        let bayesWeight: Double
        let ruleWeight: Double
        if diversity > 1.2 {
            bayesWeight = 0.65; ruleWeight = 0.35
        } else {
            bayesWeight = 0.55; ruleWeight = 0.45
        }

        let fused = bayesWeight * bayesScore + ruleWeight * ruleScore
        let agreement = 1.0 - abs(bayesScore - ruleScore)
        let conf = min(1.0, (agreement * 0.6) + (min(1.0, diversity / 2.0) * 0.4))

        // Cap extremes softly
        let final: Double
        if fused > 0.95 && conf > 0.8 { final = 0.95 }
        else if fused < 0.05 && conf > 0.8 { final = 0.05 }
        else { final = fused }

        return (final, conf)
    }
}
