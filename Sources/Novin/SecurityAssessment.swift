import Foundation

/// Threat level classification
public enum ThreatLevel: String, Codable {
    case low
    case standard
    case elevated
    case critical
}

/// Security assessment result from AI engine
public struct SecurityAssessment: Codable {
    public let threatLevel: ThreatLevel
    public let confidence: Double
    public let processingTimeMs: Double
    public let reasoning: String
    public let requestId: String?
    public let timestamp: String?
    
    // Human-readable explanations
    public let summary: String?              // Short, adaptive summary
    public let detailedReasoning: String?    // Full "why" explanation
    public let context: [String]?            // Contextual factors
    public let recommendation: String?       // What user should do
    
    public init(
        threatLevel: ThreatLevel,
        confidence: Double,
        processingTimeMs: Double,
        reasoning: String,
        requestId: String? = nil,
        timestamp: String? = nil,
        summary: String? = nil,
        detailedReasoning: String? = nil,
        context: [String]? = nil,
        recommendation: String? = nil
    ) {
        self.threatLevel = threatLevel
        self.confidence = confidence
        self.processingTimeMs = processingTimeMs
        self.reasoning = reasoning
        self.requestId = requestId
        self.timestamp = timestamp
        self.summary = summary
        self.detailedReasoning = detailedReasoning
        self.context = context
        self.recommendation = recommendation
    }

    /// PI-format JSON suitable for partner ingestion (e.g., locw.ly style)
    /// Example keys: event_type, threat.level, threat.confidence_pct, meta.reasoning, meta.request_id, meta.timestamp
    public func toPI() throws -> String {
        var metaDict: [String: Any] = [
            "reasoning": reasoning,
            "request_id": requestId as Any,
            "timestamp": timestamp as Any
        ]
        
        // Add human-readable fields if available
        if let summary = summary {
            metaDict["summary"] = summary
        }
        if let detailedReasoning = detailedReasoning {
            metaDict["detailed_reasoning"] = detailedReasoning
        }
        if let context = context {
            metaDict["context"] = context
        }
        if let recommendation = recommendation {
            metaDict["recommendation"] = recommendation
        }
        
        let payload: [String: Any] = [
            "event_type": "security_assessment",
            "threat": [
                "level": threatLevel.rawValue,
                "confidence_pct": Int(round(confidence * 100.0))
            ],
            "processing": [
                "time_ms": Int(round(processingTimeMs))
            ],
            "meta": metaDict
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
