import Foundation

/// Enterprise-grade configuration for temporal intelligence
/// Allows brands to customize dampening behavior without code changes
public struct TemporalConfiguration: Codable {
    
    // MARK: - Time Windows
    
    /// Delivery window hours (default: 9 AM - 5 PM)
    public var deliveryWindowStart: Int
    public var deliveryWindowEnd: Int
    
    /// Night hours for vigilance boost (default: 10 PM - 6 AM)
    public var nightStart: Int
    public var nightEnd: Int
    
    // MARK: - Dampening Thresholds
    
    /// Dampening factor for daytime deliveries (default: 0.4 = 60% reduction)
    public var daytimeDampeningFactor: Double
    
    /// Boost factor for night activity (default: 1.3 = 30% increase)
    public var nightVigilanceBoost: Double
    
    /// Dampening factor for pet motion (default: 0.3 = 70% reduction)
    public var petDampeningFactor: Double
    
    /// Dampening factor for home mode motion (default: 0.5 = 50% reduction)
    public var homeModeDampeningFactor: Double
    
    /// Weekend dampening factor (default: 0.6 = 40% reduction)
    public var weekendDampeningFactor: Double
    
    // MARK: - Safety Caps
    
    /// Minimum threat score (prevents over-dampening)
    public var minimumThreatScore: Double
    
    /// Maximum threat score (prevents over-boosting)
    public var maximumThreatScore: Double
    
    /// Critical event minimum score (glass break, etc.)
    public var criticalEventMinimum: Double
    
    // MARK: - Timezone
    
    /// Timezone for temporal calculations (default: device timezone)
    public var timezone: TimeZone
    
    // MARK: - User Pattern Learning
    
    /// Enable user pattern learning (default: true)
    public var enableUserPatternLearning: Bool
    
    /// Learning rate for delivery frequency (default: 0.05)
    public var deliveryLearningRate: Double
    
    /// Maximum pattern dampening from learning (default: 0.5 = 50% max reduction)
    public var maxPatternDampening: Double
    
    // MARK: - Telemetry
    
    /// Enable privacy-safe telemetry (default: true)
    public var enableTelemetry: Bool
    
    // MARK: - Presets
    
    /// Default configuration (balanced for most users)
    public static let `default` = TemporalConfiguration(
        deliveryWindowStart: 9,
        deliveryWindowEnd: 17,
        nightStart: 22,
        nightEnd: 6,
        daytimeDampeningFactor: 0.4,
        nightVigilanceBoost: 1.3,
        petDampeningFactor: 0.3,
        homeModeDampeningFactor: 0.5,
        weekendDampeningFactor: 0.6,
        minimumThreatScore: 0.2,
        maximumThreatScore: 1.0,
        criticalEventMinimum: 0.9,
        timezone: .current,
        enableUserPatternLearning: true,
        deliveryLearningRate: 0.05,
        maxPatternDampening: 0.5,
        enableTelemetry: true
    )
    
    /// Aggressive configuration (Ring-like, high sensitivity)
    public static let aggressive = TemporalConfiguration(
        deliveryWindowStart: 9,
        deliveryWindowEnd: 17,
        nightStart: 22,
        nightEnd: 6,
        daytimeDampeningFactor: 0.7,  // Less dampening
        nightVigilanceBoost: 1.5,      // More boost
        petDampeningFactor: 0.5,       // Less pet dampening
        homeModeDampeningFactor: 0.7,  // Less home dampening
        weekendDampeningFactor: 0.8,   // Less weekend dampening
        minimumThreatScore: 0.3,
        maximumThreatScore: 1.0,
        criticalEventMinimum: 0.85,
        timezone: .current,
        enableUserPatternLearning: true,
        deliveryLearningRate: 0.03,
        maxPatternDampening: 0.3,
        enableTelemetry: true
    )
    
    /// Conservative configuration (Nest-like, low false positives)
    public static let conservative = TemporalConfiguration(
        deliveryWindowStart: 8,
        deliveryWindowEnd: 18,
        nightStart: 23,
        nightEnd: 5,
        daytimeDampeningFactor: 0.25,  // More dampening
        nightVigilanceBoost: 1.2,       // Less boost
        petDampeningFactor: 0.2,        // More pet dampening
        homeModeDampeningFactor: 0.3,   // More home dampening
        weekendDampeningFactor: 0.4,    // More weekend dampening
        minimumThreatScore: 0.15,
        maximumThreatScore: 1.0,
        criticalEventMinimum: 0.95,
        timezone: .current,
        enableUserPatternLearning: true,
        deliveryLearningRate: 0.07,
        maxPatternDampening: 0.6,
        enableTelemetry: true
    )
    
    // MARK: - Validation
    
    /// Validate configuration parameters
    public func validate() throws {
        guard deliveryWindowStart >= 0 && deliveryWindowStart < 24 else {
            throw ConfigurationError.invalidDeliveryWindow
        }
        guard deliveryWindowEnd >= 0 && deliveryWindowEnd < 24 else {
            throw ConfigurationError.invalidDeliveryWindow
        }
        guard nightStart >= 0 && nightStart < 24 else {
            throw ConfigurationError.invalidNightWindow
        }
        guard nightEnd >= 0 && nightEnd < 24 else {
            throw ConfigurationError.invalidNightWindow
        }
        guard daytimeDampeningFactor > 0 && daytimeDampeningFactor <= 1.0 else {
            throw ConfigurationError.invalidDampeningFactor
        }
        guard nightVigilanceBoost >= 1.0 && nightVigilanceBoost <= 2.0 else {
            throw ConfigurationError.invalidBoostFactor
        }
        guard minimumThreatScore >= 0 && minimumThreatScore < maximumThreatScore else {
            throw ConfigurationError.invalidThreatCaps
        }
    }
}

public enum ConfigurationError: Error {
    case invalidDeliveryWindow
    case invalidNightWindow
    case invalidDampeningFactor
    case invalidBoostFactor
    case invalidThreatCaps
}

