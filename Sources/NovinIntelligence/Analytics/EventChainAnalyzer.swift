import Foundation

/// Enterprise event chain analysis for sequence detection
@available(iOS 15.0, macOS 12.0, *)
public final class EventChainAnalyzer: @unchecked Sendable {
    
    // MARK: - Configuration
    private let bufferWindow: TimeInterval = 60  // 60 second window
    private let maxBufferSize: Int = 100
    
    // MARK: - State
    private let queue = DispatchQueue(label: "com.novinintelligence.eventchain")
    private var eventBuffer: [SecurityEvent] = []
    
    // MARK: - Types
    
    public struct SecurityEvent {
        public let type: String
        public let timestamp: Date
        public let location: String
        public let confidence: Double
        public let metadata: [String: Any]
        
        public init(type: String, timestamp: Date, location: String, confidence: Double, metadata: [String: Any] = [:]) {
            self.type = type
            self.timestamp = timestamp
            self.location = location
            self.confidence = confidence
            self.metadata = metadata
        }
    }
    
    public struct ChainPattern {
        public let name: String
        public let events: [SecurityEvent]
        public let threatDelta: Double
        public let confidence: Double
        public let reasoning: String
    }
    
    // MARK: - Analysis
    
    /// Analyze event chain and detect patterns
    public func analyzeChain(_ newEvent: SecurityEvent) -> ChainPattern? {
        return queue.sync {
            // Add event to buffer
            addToBuffer(newEvent)
            
            // Clean old events outside window
            cleanBuffer()
            
            // Detect patterns
            return detectPatterns()
        }
    }
    
    /// Get recent events in buffer
    public func getRecentEvents() -> [SecurityEvent] {
        return queue.sync { eventBuffer }
    }
    
    /// Clear buffer (for testing)
    public func reset() {
        queue.sync {
            eventBuffer.removeAll()
        }
    }
    
    // MARK: - Private Methods
    
    private func addToBuffer(_ event: SecurityEvent) {
        eventBuffer.append(event)
        
        // Enforce max buffer size
        if eventBuffer.count > maxBufferSize {
            eventBuffer.removeFirst(eventBuffer.count - maxBufferSize)
        }
    }
    
    private func cleanBuffer() {
        let cutoff = Date().addingTimeInterval(-bufferWindow)
        eventBuffer.removeAll { $0.timestamp < cutoff }
    }
    
    private func detectPatterns() -> ChainPattern? {
        // Pattern 1: Doorbell → Motion → Silence = Package Delivery
        if let deliveryPattern = detectDeliveryPattern() {
            return deliveryPattern
        }
        
        // Pattern 2: Motion → Door → Motion = Potential Intrusion
        if let intrusionPattern = detectIntrusionPattern() {
            return intrusionPattern
        }
        
        // Pattern 3: Multiple Failed Door Attempts = Forced Entry Attempt
        if let forcedEntryPattern = detectForcedEntryPattern() {
            return forcedEntryPattern
        }
        
        // Pattern 4: Glass Break → Motion = Active Break-In
        if let breakInPattern = detectBreakInPattern() {
            return breakInPattern
        }
        
        // Pattern 5: Repeated Motion in Multiple Zones = Prowler
        if let prowlerPattern = detectProwlerPattern() {
            return prowlerPattern
        }
        
        return nil
    }
    
    // MARK: - Pattern Detection
    
    /// Detect: Doorbell → Motion → Silence (10-30s) = Package Delivery
    private func detectDeliveryPattern() -> ChainPattern? {
        guard eventBuffer.count >= 2 else { return nil }
        
        // Look for doorbell followed by motion, then silence
        for i in 0..<(eventBuffer.count - 1) {
            let event1 = eventBuffer[i]
            let event2 = eventBuffer[i + 1]
            
            // Doorbell → Motion at same location
            if (event1.type.contains("doorbell") || event1.type.contains("chime")) &&
               event2.type.contains("motion") &&
               event1.location == event2.location {
                
                let timeDiff = event2.timestamp.timeIntervalSince(event1.timestamp)
                
                // 2-30 second gap is typical for package drop
                if timeDiff >= 2 && timeDiff <= 30 {
                    // Check for silence after (no more events at this location)
                    let hasSubsequentActivity = eventBuffer.suffix(from: i + 2).contains { event in
                        event.location == event1.location && event.timestamp.timeIntervalSince(event2.timestamp) < 20
                    }
                    
                    if !hasSubsequentActivity {
                        return ChainPattern(
                            name: "package_delivery",
                            events: [event1, event2],
                            threatDelta: -0.4,  // Reduce threat
                            confidence: 0.85,
                            reasoning: "Doorbell + quick motion + silence = likely package delivery"
                        )
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Detect: Motion → Door → Motion (continuing) = Potential Intrusion
    private func detectIntrusionPattern() -> ChainPattern? {
        guard eventBuffer.count >= 3 else { return nil }
        
        for i in 0..<(eventBuffer.count - 2) {
            let event1 = eventBuffer[i]
            let event2 = eventBuffer[i + 1]
            let event3 = eventBuffer[i + 2]
            
            // Motion → Door → Motion (continuing activity)
            if event1.type.contains("motion") &&
               (event2.type.contains("door") || event2.type.contains("window")) &&
               event3.type.contains("motion") {
                
                let time12 = event2.timestamp.timeIntervalSince(event1.timestamp)
                let time23 = event3.timestamp.timeIntervalSince(event2.timestamp)
                
                // Events within 30 seconds
                if time12 <= 30 && time23 <= 30 {
                    return ChainPattern(
                        name: "intrusion_sequence",
                        events: [event1, event2, event3],
                        threatDelta: 0.5,  // Increase threat
                        confidence: 0.90,
                        reasoning: "Motion + door/window + continued motion = intrusion pattern"
                    )
                }
            }
        }
        
        return nil
    }
    
    /// Detect: Multiple door/window events in short time = Forced Entry
    private func detectForcedEntryPattern() -> ChainPattern? {
        let last15Seconds = Date().addingTimeInterval(-15)
        let recentDoorEvents = eventBuffer.filter { event in
            (event.type.contains("door") || event.type.contains("window")) &&
            event.timestamp >= last15Seconds
        }
        
        // 3+ door/window events in 15 seconds = forced entry attempt
        if recentDoorEvents.count >= 3 {
            return ChainPattern(
                name: "forced_entry",
                events: recentDoorEvents,
                threatDelta: 0.6,  // High threat increase
                confidence: 0.92,
                reasoning: "\(recentDoorEvents.count) door/window events in 15s = forced entry attempt"
            )
        }
        
        return nil
    }
    
    /// Detect: Glass Break → Motion = Active Break-In
    private func detectBreakInPattern() -> ChainPattern? {
        guard eventBuffer.count >= 2 else { return nil }
        
        for i in 0..<(eventBuffer.count - 1) {
            let event1 = eventBuffer[i]
            let event2 = eventBuffer[i + 1]
            
            // Glass break followed by motion
            if event1.type.contains("glass") && event2.type.contains("motion") {
                let timeDiff = event2.timestamp.timeIntervalSince(event1.timestamp)
                
                // Within 20 seconds
                if timeDiff <= 20 {
                    return ChainPattern(
                        name: "active_break_in",
                        events: [event1, event2],
                        threatDelta: 0.7,  // Critical threat increase
                        confidence: 0.95,
                        reasoning: "Glass break + motion = active break-in in progress"
                    )
                }
            }
        }
        
        return nil
    }
    
    /// Detect: Motion in multiple zones in sequence = Prowler
    private func detectProwlerPattern() -> ChainPattern? {
        let last60Seconds = Date().addingTimeInterval(-60)
        let recentMotion = eventBuffer.filter { event in
            event.type.contains("motion") && event.timestamp >= last60Seconds
        }
        
        // Motion in 3+ different locations within 60 seconds
        let uniqueLocations = Set(recentMotion.map { $0.location })
        if uniqueLocations.count >= 3 {
            return ChainPattern(
                name: "prowler_activity",
                events: recentMotion,
                threatDelta: 0.45,  // Elevated threat
                confidence: 0.88,
                reasoning: "Motion in \(uniqueLocations.count) zones in 60s = prowler pattern"
            )
        }
        
        return nil
    }
}




