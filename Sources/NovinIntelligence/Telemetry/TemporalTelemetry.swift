import Foundation

/// Enterprise AI: Privacy-safe telemetry for temporal dampening
/// No PII, no cloud sync, on-device analytics only
public class TemporalTelemetry {
    
    // MARK: - Metrics
    
    private var dampeningEvents: [DampeningEvent] = []
    private let maxEventsStored: Int = 500
    
    // MARK: - Singleton
    
    public static let shared = TemporalTelemetry()
    private init() {}
    
    // MARK: - Recording
    
    /// Record a dampening event
    public func record(
        eventType: String,
        originalScore: Double,
        dampenedScore: Double,
        dampeningType: DampeningType,
        timestamp: Date = Date()
    ) {
        let event = DampeningEvent(
            eventType: eventType,
            originalScore: originalScore,
            dampenedScore: dampenedScore,
            dampeningType: dampeningType,
            timestamp: timestamp
        )
        
        dampeningEvents.append(event)
        
        // Trim to max size
        if dampeningEvents.count > maxEventsStored {
            dampeningEvents.removeFirst(dampeningEvents.count - maxEventsStored)
        }
    }
    
    // MARK: - Analytics
    
    /// Get dampening effectiveness metrics
    public func getMetrics() -> DampeningMetrics {
        guard !dampeningEvents.isEmpty else {
            return DampeningMetrics.empty
        }
        
        let totalEvents = dampeningEvents.count
        let dampenedEvents = dampeningEvents.filter { $0.dampenedScore < $0.originalScore }
        let boostedEvents = dampeningEvents.filter { $0.dampenedScore > $0.originalScore }
        
        let averageReduction = dampenedEvents.map { $0.originalScore - $0.dampenedScore }.reduce(0, +) / Double(max(1, dampenedEvents.count))
        let averageBoost = boostedEvents.map { $0.dampenedScore - $0.originalScore }.reduce(0, +) / Double(max(1, boostedEvents.count))
        
        // Group by dampening type
        var typeBreakdown: [DampeningType: Int] = [:]
        for event in dampeningEvents {
            typeBreakdown[event.dampeningType, default: 0] += 1
        }
        
        // Recent performance (last 24 hours)
        let recentEvents = dampeningEvents.filter { abs($0.timestamp.timeIntervalSinceNow) < 24 * 3600 }
        
        return DampeningMetrics(
            totalEvents: totalEvents,
            dampenedEvents: dampenedEvents.count,
            boostedEvents: boostedEvents.count,
            averageReduction: averageReduction,
            averageBoost: averageBoost,
            typeBreakdown: typeBreakdown,
            recentEvents24h: recentEvents.count,
            effectiveness: calculateEffectiveness()
        )
    }
    
    /// Calculate overall effectiveness score
    private func calculateEffectiveness() -> Double {
        // Simple heuristic: More dampening with fewer boosts = more effective
        let metrics = getMetrics()
        guard metrics.totalEvents > 0 else { return 0.0 }
        
        let dampeningRatio = Double(metrics.dampenedEvents) / Double(metrics.totalEvents)
        let boostRatio = Double(metrics.boostedEvents) / Double(metrics.totalEvents)
        
        // Effectiveness: 70% dampening, 30% appropriate boosting
        return min(1.0, dampeningRatio * 0.7 + (1.0 - boostRatio) * 0.3)
    }
    
    /// Export metrics as JSON (privacy-safe, no PII)
    public func exportMetrics() -> String? {
        let metrics = getMetrics()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let data = try? encoder.encode(metrics),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return json
    }
    
    /// Reset telemetry (for testing)
    public func reset() {
        dampeningEvents.removeAll()
    }
}

// MARK: - Models

public struct DampeningEvent: Codable {
    let eventType: String
    let originalScore: Double
    let dampenedScore: Double
    let dampeningType: DampeningType
    let timestamp: Date
}

public enum DampeningType: String, Codable {
    case deliveryWindow = "delivery_window"
    case nightVigilance = "night_vigilance"
    case petMotion = "pet_motion"
    case homeMode = "home_mode"
    case weekend = "weekend"
    case glassBreakOverride = "glass_break_override"
    case userPattern = "user_pattern"
    case none = "none"
}

public struct DampeningMetrics: Codable {
    public let totalEvents: Int
    public let dampenedEvents: Int
    public let boostedEvents: Int
    public let averageReduction: Double
    public let averageBoost: Double
    public let typeBreakdown: [DampeningType: Int]
    public let recentEvents24h: Int
    public let effectiveness: Double
    
    public static let empty = DampeningMetrics(
        totalEvents: 0,
        dampenedEvents: 0,
        boostedEvents: 0,
        averageReduction: 0.0,
        averageBoost: 0.0,
        typeBreakdown: [:],
        recentEvents24h: 0,
        effectiveness: 0.0
    )
}

