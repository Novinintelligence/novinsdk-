import Foundation

/// Enterprise AI: On-device user pattern learning
/// Privacy-safe, no cloud sync, learns from user feedback
public class UserPatterns: Codable {
    
    // MARK: - Pattern Data
    
    /// Delivery frequency (0-1 normalized, weekly average)
    public private(set) var deliveryFrequency: Double
    
    /// False positive history by event type
    public private(set) var falsePositiveHistory: [String: Int]
    
    /// Event dismissal timestamps for pattern analysis
    private var dismissalTimestamps: [Date]
    
    /// Total events assessed
    public private(set) var totalEventsAssessed: Int
    
    /// Total user interactions
    public private(set) var totalUserInteractions: Int
    
    /// Last learning update
    public private(set) var lastUpdated: Date
    
    // MARK: - Configuration
    
    private let maxHistorySize: Int = 1000
    private let learningRate: Double
    
    // MARK: - Initialization
    
    public init(learningRate: Double = 0.05) {
        self.deliveryFrequency = 0.3  // Default: moderate delivery frequency
        self.falsePositiveHistory = [:]
        self.dismissalTimestamps = []
        self.totalEventsAssessed = 0
        self.totalUserInteractions = 0
        self.lastUpdated = Date()
        self.learningRate = learningRate
    }
    
    // MARK: - Learning Methods
    
    /// Update patterns based on user feedback
    /// - Parameters:
    ///   - eventType: Type of event (e.g., "doorbell_motion")
    ///   - wasFalsePositive: Whether user marked as false positive
    ///   - timestamp: When the event occurred
    public func learn(eventType: String, wasFalsePositive: Bool, timestamp: Date = Date()) {
        totalUserInteractions += 1
        
        if wasFalsePositive {
            // Increment false positive count
            falsePositiveHistory[eventType, default: 0] += 1
            dismissalTimestamps.append(timestamp)
            
            // Update delivery frequency if delivery-related event
            if eventType.contains("doorbell") || eventType.contains("motion") {
                deliveryFrequency = min(1.0, deliveryFrequency + learningRate)
            }
            
            // Trim history to max size
            if dismissalTimestamps.count > maxHistorySize {
                dismissalTimestamps.removeFirst(dismissalTimestamps.count - maxHistorySize)
            }
        }
        
        lastUpdated = Date()
    }
    
    /// Record event assessment (for telemetry)
    public func recordAssessment() {
        totalEventsAssessed += 1
    }
    
    /// Get dampening factor for event type based on learned patterns
    /// - Parameter eventType: Event type to analyze
    /// - Returns: Dampening factor (0-1, lower = more dampening)
    public func getDampeningFactor(for eventType: String) -> Double {
        let falsePositiveCount = falsePositiveHistory[eventType] ?? 0
        
        // More false positives = more dampening
        if falsePositiveCount > 20 {
            return 0.5  // Heavy dampening
        } else if falsePositiveCount > 10 {
            return 0.7  // Moderate dampening
        } else if falsePositiveCount > 5 {
            return 0.85 // Light dampening
        }
        
        return 1.0  // No pattern-based dampening
    }
    
    /// Get delivery pattern insights
    public func getDeliveryPatternInsights() -> DeliveryPatternInsights {
        // Analyze dismissal timestamps for patterns
        let recentDismissals = dismissalTimestamps.filter { timestamp in
            abs(timestamp.timeIntervalSinceNow) < 7 * 24 * 3600  // Last 7 days
        }
        
        let calendar = Calendar.current
        var hourHistogram: [Int: Int] = [:]
        var dayHistogram: [Int: Int] = [:]
        
        for timestamp in recentDismissals {
            let hour = calendar.component(.hour, from: timestamp)
            let weekday = calendar.component(.weekday, from: timestamp)
            
            hourHistogram[hour, default: 0] += 1
            dayHistogram[weekday, default: 0] += 1
        }
        
        // Find peak delivery hours
        let peakDeliveryHour = hourHistogram.max(by: { $0.value < $1.value })?.key ?? 14
        let peakDeliveryDay = dayHistogram.max(by: { $0.value < $1.value })?.key ?? 3  // Wednesday
        
        return DeliveryPatternInsights(
            averageDeliveriesPerWeek: Double(recentDismissals.count),
            peakDeliveryHour: peakDeliveryHour,
            peakDeliveryDay: peakDeliveryDay,
            deliveryFrequency: deliveryFrequency
        )
    }
    
    /// Get false positive rate
    public func getFalsePositiveRate() -> Double {
        guard totalEventsAssessed > 0 else { return 0.0 }
        let totalFalsePositives = falsePositiveHistory.values.reduce(0, +)
        return Double(totalFalsePositives) / Double(totalEventsAssessed)
    }
    
    /// Reset patterns (for testing or user request)
    public func reset() {
        deliveryFrequency = 0.3
        falsePositiveHistory.removeAll()
        dismissalTimestamps.removeAll()
        totalEventsAssessed = 0
        totalUserInteractions = 0
        lastUpdated = Date()
    }
    
    // MARK: - Persistence
    
    private static let storageKey = "com.novinintelligence.userpatterns"
    
    /// Save patterns to UserDefaults (on-device, privacy-safe)
    public func save() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
    
    /// Load patterns from UserDefaults
    public static func load(learningRate: Double = 0.05) -> UserPatterns {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let patterns = try? JSONDecoder().decode(UserPatterns.self, from: data) else {
            return UserPatterns(learningRate: learningRate)
        }
        return patterns
    }
}

/// Insights from delivery pattern analysis
public struct DeliveryPatternInsights {
    public let averageDeliveriesPerWeek: Double
    public let peakDeliveryHour: Int
    public let peakDeliveryDay: Int  // 1=Sunday, 2=Monday, etc.
    public let deliveryFrequency: Double
}

