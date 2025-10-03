import XCTest
@testable import NovinIntelligence

/// Event chain analysis tests (P1.1 feature)
@available(iOS 15.0, macOS 12.0, *)
final class EventChainTests: XCTestCase {
    
    var sdk: NovinIntelligence!
    var analyzer: EventChainAnalyzer!
    
    override func setUpWithError() throws {
        sdk = NovinIntelligence.shared
        analyzer = EventChainAnalyzer()
        Task {
            try await sdk.initialize()
        }
    }
    
    override func tearDown() {
        analyzer.reset()
    }
    
    // MARK: - Package Delivery Pattern
    
    func testPackageDeliveryPattern() async throws {
        // Scenario: Doorbell → Motion → Silence = Package delivery
        let now = Date()
        
        // Event 1: Doorbell
        let doorbell = EventChainAnalyzer.SecurityEvent(
            type: "doorbell_chime",
            timestamp: now,
            location: "front_door",
            confidence: 0.9
        )
        _ = analyzer.analyzeChain(doorbell)
        
        // Event 2: Motion 5 seconds later
        let motion = EventChainAnalyzer.SecurityEvent(
            type: "motion",
            timestamp: now.addingTimeInterval(5),
            location: "front_door",
            confidence: 0.8
        )
        let pattern = analyzer.analyzeChain(motion)
        
        // Should detect package delivery pattern
        XCTAssertNotNil(pattern)
        XCTAssertEqual(pattern?.name, "package_delivery")
        XCTAssertTrue(pattern!.threatDelta < 0, "Should reduce threat")
        print("✅ Detected package delivery pattern: \(pattern!.reasoning)")
        
        // Test with SDK integration
        let json = """
        {
            "type": "motion",
            "timestamp": \(Date().timeIntervalSince1970),
            "confidence": 0.8,
            "metadata": {
                "location": "front_door"
            }
        }
        """
        
        let assessment = try await sdk.assess(requestJson: json)
        print("📊 Package delivery threat: \(assessment.threatLevel.rawValue)")
    }
    
    // MARK: - Intrusion Pattern
    
    func testIntrusionPattern() async throws {
        // Scenario: Motion → Door → Motion = Intrusion
        let now = Date()
        
        let motion1 = EventChainAnalyzer.SecurityEvent(
            type: "motion",
            timestamp: now,
            location: "backyard",
            confidence: 0.7
        )
        _ = analyzer.analyzeChain(motion1)
        
        let door = EventChainAnalyzer.SecurityEvent(
            type: "door",
            timestamp: now.addingTimeInterval(10),
            location: "back_door",
            confidence: 0.9
        )
        _ = analyzer.analyzeChain(door)
        
        let motion2 = EventChainAnalyzer.SecurityEvent(
            type: "motion",
            timestamp: now.addingTimeInterval(20),
            location: "kitchen",
            confidence: 0.8
        )
        let pattern = analyzer.analyzeChain(motion2)
        
        XCTAssertNotNil(pattern)
        XCTAssertEqual(pattern?.name, "intrusion_sequence")
        XCTAssertTrue(pattern!.threatDelta > 0, "Should increase threat")
        print("✅ Detected intrusion pattern: \(pattern!.reasoning)")
    }
    
    // MARK: - Forced Entry Pattern
    
    func testForcedEntryPattern() async throws {
        // Scenario: Multiple door attempts in 15 seconds
        let now = Date()
        
        for i in 0..<4 {
            let event = EventChainAnalyzer.SecurityEvent(
                type: "door",
                timestamp: now.addingTimeInterval(Double(i * 3)),
                location: "front_door",
                confidence: 0.9
            )
            _ = analyzer.analyzeChain(event)
        }
        
        // Last event should trigger forced entry pattern
        let lastEvent = EventChainAnalyzer.SecurityEvent(
            type: "door",
            timestamp: now.addingTimeInterval(12),
            location: "front_door",
            confidence: 0.9
        )
        let pattern = analyzer.analyzeChain(lastEvent)
        
        XCTAssertNotNil(pattern)
        XCTAssertEqual(pattern?.name, "forced_entry")
        XCTAssertTrue(pattern!.threatDelta > 0.5, "Should significantly increase threat")
        print("✅ Detected forced entry pattern: \(pattern!.reasoning)")
    }
    
    // MARK: - Break-In Pattern
    
    func testBreakInPattern() async throws {
        // Scenario: Glass break → Motion = Active break-in
        let now = Date()
        
        let glassBreak = EventChainAnalyzer.SecurityEvent(
            type: "glass_break",
            timestamp: now,
            location: "window",
            confidence: 0.95
        )
        _ = analyzer.analyzeChain(glassBreak)
        
        let motion = EventChainAnalyzer.SecurityEvent(
            type: "motion",
            timestamp: now.addingTimeInterval(5),
            location: "living_room",
            confidence: 0.8
        )
        let pattern = analyzer.analyzeChain(motion)
        
        XCTAssertNotNil(pattern)
        XCTAssertEqual(pattern?.name, "active_break_in")
        XCTAssertTrue(pattern!.threatDelta > 0.6, "Should be critical threat increase")
        print("✅ Detected active break-in pattern: \(pattern!.reasoning)")
    }
    
    // MARK: - Prowler Pattern
    
    func testProwlerPattern() async throws {
        // Scenario: Motion in 3+ different zones within 60 seconds
        let now = Date()
        
        let locations = ["backyard", "side_yard", "front_yard", "porch"]
        for (index, location) in locations.enumerated() {
            let event = EventChainAnalyzer.SecurityEvent(
                type: "motion",
                timestamp: now.addingTimeInterval(Double(index * 15)),
                location: location,
                confidence: 0.7
            )
            _ = analyzer.analyzeChain(event)
        }
        
        // Last event should trigger prowler pattern
        let lastEvent = EventChainAnalyzer.SecurityEvent(
            type: "motion",
            timestamp: now.addingTimeInterval(50),
            location: "driveway",
            confidence: 0.7
        )
        let pattern = analyzer.analyzeChain(lastEvent)
        
        XCTAssertNotNil(pattern)
        XCTAssertEqual(pattern?.name, "prowler_activity")
        XCTAssertTrue(pattern!.threatDelta > 0.4, "Should elevate threat")
        print("✅ Detected prowler pattern: \(pattern!.reasoning)")
    }
    
    // MARK: - No False Positive
    
    func testNoFalsePatternDetection() async throws {
        // Single event should not trigger any pattern
        let event = EventChainAnalyzer.SecurityEvent(
            type: "motion",
            timestamp: Date(),
            location: "living_room",
            confidence: 0.5
        )
        let pattern = analyzer.analyzeChain(event)
        
        XCTAssertNil(pattern, "Single event should not match any pattern")
        print("✅ No false pattern detection")
    }
}



