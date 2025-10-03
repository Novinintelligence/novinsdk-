import XCTest
import NovinIntelligence

@available(iOS 15.0, *)
final class EnterpriseFeatureTests: XCTestCase {
    
    var sdk: NovinIntelligence!
    
    override func setUp() async throws {
        sdk = NovinIntelligence.shared
        try await sdk.initialize()
        sdk.setSystemMode("standard")
    }
    
    // MARK: - Configuration Tests
    
    func testDefaultConfiguration() async throws {
        let config = sdk.getTemporalConfiguration()
        
        XCTAssertEqual(config.deliveryWindowStart, 9)
        XCTAssertEqual(config.deliveryWindowEnd, 17)
        XCTAssertEqual(config.daytimeDampeningFactor, 0.4)
        XCTAssertEqual(config.nightVigilanceBoost, 1.3)
        XCTAssertTrue(config.enableUserPatternLearning)
        XCTAssertTrue(config.enableTelemetry)
        
        print("DEFAULT_CONFIG: ✅ Validated")
    }
    
    func testAggressiveConfiguration() async throws {
        // Configure for aggressive mode (Ring-like)
        try sdk.configure(temporal: .aggressive)
        
        let config = sdk.getTemporalConfiguration()
        
        XCTAssertEqual(config.daytimeDampeningFactor, 0.7)  // Less dampening
        XCTAssertEqual(config.nightVigilanceBoost, 1.5)      // More boost
        
        print("AGGRESSIVE_CONFIG: ✅ Ring-like sensitivity configured")
    }
    
    func testConservativeConfiguration() async throws {
        // Configure for conservative mode (Nest-like)
        try sdk.configure(temporal: .conservative)
        
        let config = sdk.getTemporalConfiguration()
        
        XCTAssertEqual(config.daytimeDampeningFactor, 0.25)  // More dampening
        XCTAssertEqual(config.nightVigilanceBoost, 1.2)       // Less boost
        
        print("CONSERVATIVE_CONFIG: ✅ Nest-like low false positives configured")
    }
    
    // MARK: - User Pattern Learning Tests
    
    func testUserPatternLearning() async throws {
        // Reset patterns first
        sdk.resetUserPatterns()
        
        // Simulate user marking doorbell events as false positives
        for _ in 0..<10 {
            sdk.provideFeedback(eventType: "doorbell_motion", wasFalsePositive: true)
        }
        
        let insights = sdk.getUserPatternInsights()
        
        XCTAssertGreaterThan(insights.deliveryFrequency, 0.3)  // Should increase
        print("USER_PATTERN_LEARNING: ✅ Delivery frequency learned: \(insights.deliveryFrequency)")
    }
    
    func testUserPatternPersistence() async throws {
        // Provide feedback
        sdk.provideFeedback(eventType: "doorbell_motion", wasFalsePositive: true)
        
        // Patterns should persist across restarts
        let patterns = UserPatterns.load()
        
        XCTAssertGreaterThan(patterns.totalUserInteractions, 0)
        print("USER_PATTERN_PERSISTENCE: ✅ Patterns saved to UserDefaults")
    }
    
    // MARK: - Telemetry Tests
    
    func testTelemetryRecording() async throws {
        // Process some events to generate telemetry
        let event = """
        {
            "type": "doorbell_chime",
            "confidence": 0.92,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "front_door",
                "home_mode": "away"
            },
            "events": [
                {
                    "type": "doorbell_chime",
                    "confidence": 0.92
                },
                {
                    "type": "motion",
                    "confidence": 0.88
                }
            ]
        }
        """
        
        _ = try await sdk.assessPI(requestJson: event)
        
        let metrics = sdk.getTelemetryMetrics()
        
        XCTAssertGreaterThan(metrics.totalEvents, 0)
        print("TELEMETRY_RECORDING: ✅ Events: \(metrics.totalEvents), Effectiveness: \(metrics.effectiveness)")
    }
    
    func testTelemetryExport() async throws {
        let json = sdk.exportTelemetry()
        
        XCTAssertNotNil(json)
        XCTAssertTrue(json!.contains("totalEvents"))
        XCTAssertTrue(json!.contains("effectiveness"))
        
        print("TELEMETRY_EXPORT: ✅ JSON exported:\n\(json!)")
    }
    
    // MARK: - Timezone Tests
    
    func testTimezoneHandling() async throws {
        // Configure for PST timezone
        var pstConfig = TemporalConfiguration.default
        pstConfig.timezone = TimeZone(identifier: "America/Los_Angeles")!
        
        try sdk.configure(temporal: pstConfig)
        
        let config = sdk.getTemporalConfiguration()
        XCTAssertEqual(config.timezone.identifier, "America/Los_Angeles")
        
        print("TIMEZONE_HANDLING: ✅ PST timezone configured")
    }
    
    // MARK: - Integration Tests
    
    func testDaytimeDoorbellWithConfiguration() async throws {
        // Use conservative config
        try sdk.configure(temporal: .conservative)
        
        let event = """
        {
            "type": "doorbell_chime",
            "confidence": 0.92,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "front_door",
                "home_mode": "away"
            },
            "events": [
                {
                    "type": "doorbell_chime",
                    "confidence": 0.92
                },
                {
                    "type": "motion",
                    "confidence": 0.88
                }
            ]
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: event)
        print("CONSERVATIVE_DOORBELL_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
        // Conservative mode should dampen more
        XCTAssertTrue(pi.contains("low") || pi.contains("standard"))
    }
    
    func testAggressiveNightActivity() async throws {
        // Use aggressive config
        try sdk.configure(temporal: .aggressive)
        
        let nightTime = Date().addingTimeInterval(-3600 * 8)  // Simulate night
        let event = """
        {
            "type": "motion",
            "confidence": 0.88,
            "timestamp": \(nightTime.timeIntervalSince1970),
            "metadata": {
                "location": "backyard",
                "home_mode": "away"
            },
            "events": [
                {
                    "type": "motion",
                    "confidence": 0.88
                }
            ]
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: event)
        print("AGGRESSIVE_NIGHT_MOTION_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
        // Aggressive mode should boost night threats
        XCTAssertTrue(pi.contains("elevated") || pi.contains("critical") || pi.contains("standard"))
    }
}

