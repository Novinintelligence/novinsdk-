import Foundation
import os.log

@available(iOS 15.0, macOS 12.0, *)
public struct ReasoningSwift {
    public struct Result {
        public let assessment: String
        public let confidence: Double
        public let chain: [String]
        public let factors: [String]
        public let recommendations: [String]
        public let riskScore: Double

        public init(assessment: String, confidence: Double, chain: [String], factors: [String], recommendations: [String], riskScore: Double) {
            self.assessment = assessment
            self.confidence = confidence
            self.chain = chain
            self.factors = factors
            self.recommendations = recommendations
            self.riskScore = riskScore
        }
    }
    
    // Public initializer so external modules can construct ReasoningSwift
    public init() {}

    // MARK: - Rules storage
    private var rules: [Rule] = []

    // MARK: - Public API
    @discardableResult
    public mutating func loadRules() -> Int {
        // Load from bundled JSON if available (SPM resources)
        if let url = Bundle.module.url(forResource: "rules", withExtension: "json", subdirectory: "Rules") ??
                     Bundle.module.url(forResource: "rules", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            self.rules = array.compactMap { d in
                guard let name = d["name"] as? String,
                      let conditions = d["conditions"] as? [String],
                      let weight = d["weight"] as? Double,
                      let score = d["score"] as? Double else { return nil }
                return Rule(name: name, conditions: conditions, weight: weight, score: score, description: d["description"] as? String)
            }
            return rules.count
        }
        // Fallback minimal rules
        self.rules = [
            Rule(name: "night_motion_suspicious", conditions: ["time_night", "event_motion"], weight: 1.5, score: 0.75, description: nil),
            Rule(name: "door_open_away", conditions: ["away_mode", "event_door"], weight: 2.0, score: 0.9, description: nil)
        ]
        let fallbackCount = self.rules.count
        Logger(subsystem: "com.novinintelligence", category: "rules").warning("Rules JSON not found in bundle; using fallback rules (\(fallbackCount)).")
        return rules.count
    }

    func reason(request: [String: Any], features: [String: Double]? = nil) -> Result {
        // Enhanced reasoning: Combine traditional rules with CoT reasoning
        let traditionalResult = reasonTraditional(request: request, features: features)
        let cotResult = reasonWithCoT(request: request, features: features)
        
        // Fuse both approaches for enterprise-grade intelligence
        let fusedScore = (traditionalResult.riskScore * 0.6) + (cotResult.riskScore * 0.4)
        let fusedConfidence = max(traditionalResult.confidence, cotResult.confidence)
        let fusedAssessment = assessmentFor(score: fusedScore)
        let fusedChain = traditionalResult.chain + ["CoT Analysis:"] + cotResult.chain
        let fusedFactors = traditionalResult.factors + cotResult.factors
        let fusedRecs = recommendationsFor(score: fusedScore, matches: [])
        
        return Result(assessment: fusedAssessment, confidence: fusedConfidence, chain: fusedChain, factors: fusedFactors, recommendations: fusedRecs, riskScore: fusedScore)
    }
    
    // MARK: - Traditional Rule-Based Reasoning (Original)
    private func reasonTraditional(request: [String: Any], features: [String: Double]? = nil) -> Result {
        let matches = applyRules(request: request, features: features)
        let (score, details) = calculateRiskScore(from: matches)
        let assessment = assessmentFor(score: score)
        let recs = recommendationsFor(score: score, matches: matches)
        let chain = buildChain(matches: matches, score: score)
        let overallConfidence = calculateOverallConfidence(matches: matches, features: features)
        return Result(assessment: assessment, confidence: overallConfidence, chain: chain, factors: details, recommendations: recs, riskScore: score)
    }

    // MARK: - Rule evaluation
    private func applyRules(request: [String: Any], features: [String: Double]?) -> [RuleMatch] {
        var results: [RuleMatch] = []
        for r in rules {
            if evaluate(rule: r, request: request, features: features) {
                let conf = calculateRuleConfidence(rule: r, request: request, features: features)
                results.append(RuleMatch(name: r.name, weight: r.weight, score: r.score, confidence: conf))
            }
        }
        return results
    }

    private func evaluate(rule: Rule, request: [String: Any], features: [String: Double]?) -> Bool {
        var matched = 0
        for cond in rule.conditions {
            if evaluateCondition(cond, features: features, request: request) { matched += 1 }
        }
        let ratio = Double(matched) / Double(max(1, rule.conditions.count))
        return ratio >= 0.7
    }

    private func evaluateCondition(_ condition: String, features: [String: Double]?, request: [String: Any]) -> Bool {
        // Temporal
        if condition == "time_night" { return (features?["hour_cos"] ?? 0.0) < -0.5 }
        if condition == "time_day" { return (features?["hour_cos"] ?? 0.0) >= -0.5 }
        if condition == "recent_event" { return (features?["hours_since_last_event"] ?? 1.0) < 0.1 }
        if condition == "unusual_hour" {
            let c = features?["hour_cos"] ?? 0.0
            let s = features?["hour_sin"] ?? 0.0
            let usual = (c > -0.7 && s > -0.7)
            return !usual
        }
        // Event
        if condition.hasPrefix("event_") { return (features?[condition] ?? 0.0) > 0.5 }
        // Spatial
        if condition == "high_crime" { return (features?["crime_rate_24h"] ?? 0.0) > 0.2 }
        if condition == "low_crime" { return (features?["crime_rate_24h"] ?? 0.0) < 0.05 }
        // Behavioral
        if condition == "away_mode" { return (request["home_mode"] as? String) == "away" }
        if condition == "high_risk_user" { return (features?["user_risk_score"] ?? 0.0) > 0.6 }
        if condition == "unusual_activity" { return (features?["activity_consistency"] ?? 0.5) < 0.3 }
        // Sensor
        if condition == "multiple_sensors" { return (features?["sensor_count"] ?? 0.0) > 0.5 }
        if condition == "high_confidence" { return (features?["event_confidence"] ?? 0.0) > 0.7 }
        return true
    }

    // MARK: - Scoring
    private func calculateRiskScore(from matches: [RuleMatch]) -> (score: Double, details: [String]) {
        guard !matches.isEmpty else { return (0.5, ["No rules matched"]) }
        var totalWeight = 0.0
        var weighted = 0.0
        var details: [String] = []
        for m in matches {
            let eScore = m.score * m.confidence
            let eWeight = m.weight * m.confidence
            totalWeight += eWeight
            weighted += eWeight * eScore
            details.append("\(m.name) (conf: \(String(format: "%.0f", m.confidence*100))%)")
        }
        let s = totalWeight > 0 ? (weighted / totalWeight) : 0.5
        return (s, details)
    }

    private func calculateRuleConfidence(rule: Rule, request: [String: Any], features: [String: Double]?) -> Double {
        var c = 0.7
        if let f = features {
            if (f["crime_rate_24h"] ?? 0.0) > 0.3 { c += 0.1 }
            if (f["sensor_count"] ?? 0.0) > 0.7 { c += 0.1 }
            if (f["event_confidence"] ?? 0.0) > 0.8 { c += 0.1 }
            if (request["home_mode"] as? String) == "away" { c += 0.05 }
        }
        return min(1.0, max(0.3, c))
    }

    private func calculateOverallConfidence(matches: [RuleMatch], features: [String: Double]?) -> Double {
        guard !matches.isEmpty else { return 0.5 }
        let avgRuleConf = matches.reduce(0.0) { $0 + $1.confidence } / Double(matches.count)
        let evidenceQuality: Double
        if let f = features, !f.isEmpty {
            let rel = f.filter { $0.key.hasPrefix("event_") || $0.key.hasPrefix("crime_") || $0.key.contains("confidence") }
            if rel.isEmpty { evidenceQuality = 0.5 }
            else {
                let vals = Array(rel.values)
                let mean = vals.reduce(0.0, +) / Double(vals.count)
                let varc = vals.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(vals.count)
                evidenceQuality = min(1.0, sqrt(max(0, varc)) * 2.0)
            }
        } else { evidenceQuality = 0.5 }
        return min(1.0, (avgRuleConf * 0.6) + (evidenceQuality * 0.4))
    }

    private func assessmentFor(score: Double) -> String {
        switch score {
        case 0.9...1.0: return "CRITICAL"
        case 0.7..<0.9: return "ELEVATED"
        case 0.4..<0.7: return "STANDARD"
        default: return "LOW"
        }
    }

    private func recommendationsFor(score: Double, matches: [RuleMatch]) -> [String] {
        var recs: [String] = []
        switch score {
        case 0.9...1.0:
            recs += ["IMMEDIATE ACTION REQUIRED","Send emergency alert","Activate all cameras"]
        case 0.7..<0.9:
            recs += ["HIGH PRIORITY ALERT","Notify homeowner","Review camera footage"]
        case 0.4..<0.7:
            recs += ["MONITORING ACTIVE","Continue surveillance"]
        default:
            recs += ["Normal operation","Baseline monitoring"]
        }
        return recs
    }

    private func buildChain(matches: [RuleMatch], score: Double) -> [String] {
        var chain: [String] = []
        chain.append("Rule Engine Analysis:")
        chain.append("• Evaluated \(rules.count) rules")
        chain.append("• \(matches.count) rules activated")
        chain.append("Risk calculation: weighted average = \(String(format: "%.3f", score))")
        chain.append("Assessment: \(assessmentFor(score: score))")
        return chain
    }

    // MARK: - Chain-of-Thought Reasoning Engine (Enterprise AI)
    private func reasonWithCoT(request: [String: Any], features: [String: Double]?) -> Result {
        var thoughts: [ThoughtStep] = []
        var currentContext = request
        var score: Double = 0.5  // Neutral start
        var confidence: Double = 0.7
        
        // Step 1: Observe raw inputs (like LLM token-by-token processing)
        let timestamp = features?["hour_cos"] ?? 0.0
        let homeMode = currentContext["home_mode"] as? String ?? "unknown"
        let eventType = currentContext["type"] as? String ?? "unknown"
        let eventConfidence = features?["event_confidence"] ?? 0.5
        
        thoughts.append(ThoughtStep(
            observation: "Event: \(eventType) (confidence: \(Int(eventConfidence * 100))%)",
            inference: "Initial event classification and reliability assessment",
            confidence: 0.9,
            nextQuery: "What time context?"
        ))
        
        // Step 2: Recursive inference chain (mimics LLM autoregression)
        func inferNext(_ priorThought: ThoughtStep) -> ThoughtStep? {
            switch priorThought.nextQuery {
            case "What time context?":
                let isNight = timestamp < -0.5  // hour_cos < -0.5 means night
                let timeContext = isNight ? "Nighttime (22:00-06:00)" : "Daytime (06:00-22:00)"
                let timeImpact = isNight ? 0.3 : -0.1
                score += timeImpact
                confidence += isNight ? 0.1 : 0.05
                
                return ThoughtStep(
                    observation: "Time: \(timeContext)",
                    inference: isNight ? "Nighttime raises baseline threat by 30%" : "Daytime allows benign activity (-10%)",
                    confidence: 0.95,
                    nextQuery: "Check home occupancy status?"
                )
                
            case "Check home occupancy status?":
                let isAway = homeMode == "away"
                let occupancyImpact = isAway ? 0.4 : -0.2
                score += occupancyImpact
                confidence += isAway ? 0.15 : 0.05
                
                return ThoughtStep(
                    observation: "Home mode: \(homeMode)",
                    inference: isAway ? "Away mode significantly increases threat (+40%)" : "Home mode reduces threat (-20%)",
                    confidence: 0.9,
                    nextQuery: "Analyze event severity?"
                )
                
            case "Analyze event severity?":
                var severityImpact = 0.0
                var severityReasoning = ""
                
                switch eventType {
                case "glassbreak":
                    severityImpact = 0.6
                    severityReasoning = "Glassbreak = forced entry indicator (+60%)"
                case "motion":
                    severityImpact = eventConfidence > 0.8 ? 0.3 : 0.1
                    severityReasoning = "Motion detected: \(eventConfidence > 0.8 ? "High confidence (+30%)" : "Low confidence (+10%)")"
                case "door":
                    severityImpact = 0.4
                    severityReasoning = "Door event: potential entry point (+40%)"
                case "face":
                    let trustLevel = features?["user_risk_profile.trust_level"] ?? 0.5
                    severityImpact = trustLevel < 0.3 ? 0.5 : -0.3
                    severityReasoning = trustLevel < 0.3 ? "Unknown face detected (+50%)" : "Known face, low threat (-30%)"
                case "pet":
                    severityImpact = -0.4
                    severityReasoning = "Pet motion: false positive filter (-40%)"
                default:
                    severityImpact = 0.1
                    severityReasoning = "Unknown event type: minimal threat (+10%)"
                }
                
                score += severityImpact
                confidence += abs(severityImpact) * 0.2
                
                return ThoughtStep(
                    observation: "Event severity analysis",
                    inference: severityReasoning,
                    confidence: 0.85,
                    nextQuery: "Cross-reference with external factors?"
                )
                
            case "Cross-reference with external factors?":
                let crimeRate = features?["crime_rate_24h"] ?? 0.0
                let sensorCount = features?["sensor_count"] ?? 1.0
                
                let crimeImpact = crimeRate * 0.3  // Crime rate amplifies threat
                let sensorImpact = sensorCount > 2.0 ? 0.1 : -0.1  // Multiple sensors = more reliable
                
                score += crimeImpact + sensorImpact
                confidence += (crimeRate > 0.3 ? 0.1 : 0.0) + (sensorCount > 2.0 ? 0.05 : 0.0)
                
                let externalReasoning = "Crime context: \(Int(crimeRate * 100))% rate (\(crimeImpact > 0 ? "+" : "")\(Int(crimeImpact * 100))%) | Sensors: \(Int(sensorCount)) active (\(sensorImpact > 0 ? "+" : "")\(Int(sensorImpact * 100))%)"
                
                return ThoughtStep(
                    observation: "External context analysis",
                    inference: externalReasoning,
                    confidence: 0.8,
                    nextQuery: nil  // End chain
                )
                
            default:
                return nil  // Chain ends
            }
        }
        
        // Build the reasoning chain
        var current = thoughts.last!
        while let next = inferNext(current) {
            thoughts.append(next)
            current = next
        }
        
        // Final score normalization and confidence adjustment
        let finalScore = min(1.0, max(0.0, score))
        let finalConfidence = min(1.0, max(0.3, confidence))
        
        // Generate human-like explanation
        let explanation = thoughts.map { "\($0.observation): \($0.inference) (\(Int($0.confidence * 100))%)" }.joined(separator: " → ")
        let factors = thoughts.compactMap { $0.inference.contains("+") || $0.inference.contains("-") ? $0.observation : nil }
        let chain = ["CoT Reasoning Chain:"] + thoughts.map { "• \($0.observation) → \($0.inference)" }
        
        return Result(
            assessment: assessmentFor(score: finalScore),
            confidence: finalConfidence,
            chain: chain,
            factors: factors,
            recommendations: recommendationsFor(score: finalScore, matches: []),
            riskScore: finalScore
        )
    }
    
    // MARK: - Types
    private struct Rule { let name: String; let conditions: [String]; let weight: Double; let score: Double; let description: String? }
    private struct RuleMatch { let name: String; let weight: Double; let score: Double; let confidence: Double }
    private struct ThoughtStep {
        let observation: String
        let inference: String
        let confidence: Double
        let nextQuery: String?
    }
}

// Legacy pattern types removed in math+rules refactor
