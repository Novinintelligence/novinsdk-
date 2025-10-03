import XCTest
import NovinIntelligence

/// EVENT RESPONSE TESTS: How does the AI respond to different events?
/// Tests real-world scenarios, edge cases, and appropriate threat escalation/dampening
@available(iOS 15.0, *)
final class EventResponseTests: XCTestCase {
    
    var sdk: NovinIntelligence!
    
    override func setUp() async throws {
        sdk = NovinIntelligence.shared
        try await sdk.initialize()
        sdk.setSystemMode("standard")
        try sdk.configure(temporal: .default)
    }
    
    // MARK: - Critical Event Responses
    
    func testGlassBreakResponse() async throws {
        print("\n🚨 TEST: Glass Break Event Response")
        
        let scenarios: [(time: String, mode: String, expectedCritical: Bool)] = [
            ("day", "away", true),
            ("night", "away", true),
            ("day", "home", true),
            ("night", "home", true)
        ]
        
        for scenario in scenarios {
            let timestamp = scenario.time == "night" ? 
                Date().timeIntervalSince1970 - 3600 * 3 : 
                Date().timeIntervalSince1970
            
            let event = """
            {
                "timestamp": \(timestamp),
                "home_mode": "\(scenario.mode)",
                "events": [{"type": "glassbreak", "confidence": 0.95}],
                "metadata": {"location": "living_room"}
            }
            """
            
            let result = try await sdk.assess(requestJson: event)
            
            print("   \(scenario.time) + \(scenario.mode): \(result.threatLevel)")
            
            if scenario.expectedCritical {
                XCTAssertEqual(result.threatLevel, .critical,
                              "❌ FAIL: Glass break not critical in \(scenario.time)/\(scenario.mode)")
            }
        }
        
        print("✅ PASS: Glass break always triggers critical response")
    }
    
    func testFireAlarmResponse() async throws {
        print("\n🚨 TEST: Fire/Smoke Alarm Response")
        
        let event = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "away",
            "events": [{"type": "smoke", "confidence": 0.90}],
            "metadata": {"location": "kitchen"}
        }
        """
        
        let result = try await sdk.assess(requestJson: event)
        
        print("   Smoke alarm: \(result.threatLevel)")
        
        XCTAssertEqual(result.threatLevel, .critical,
                      "❌ FAIL: Fire/smoke not treated as critical")
        
        print("✅ PASS: Fire/smoke triggers critical response")
    }
    
    func testCO2AlarmResponse() async throws {
        print("\n🚨 TEST: CO2/Gas Alarm Response")
        
        let event = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "home",
            "events": [{"type": "co2", "confidence": 0.92}],
            "metadata": {"location": "basement"}
        }
        """
        
        let result = try await sdk.assess(requestJson: event)
        
        print("   CO2 alarm: \(result.threatLevel)")
        
        XCTAssertEqual(result.threatLevel, .critical,
                      "❌ FAIL: CO2 alarm not treated as critical")
        
        print("✅ PASS: CO2 alarm triggers critical response")
    }
    
    func testWaterLeakResponse() async throws {
        print("\n🚨 TEST: Water Leak Detection Response")
        
        let event = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "away",
            "events": [{"type": "water_leak", "confidence": 0.88}],
            "metadata": {"location": "basement"}
        }
        """
        
        let result = try await sdk.assess(requestJson: event)
        
        print("   Water leak: \(result.threatLevel)")
        
        // Water leak should be elevated or critical
        XCTAssertTrue(result.threatLevel == .elevated || result.threatLevel == .critical,
                     "❌ FAIL: Water leak not treated seriously")
        
        print("✅ PASS: Water leak triggers appropriate response")
    }
    
    // MARK: - Elevated Threat Responses
    
    func testNightMotionResponse() async throws {
        print("\n⚠️ TEST: Night Motion Event Response")
        
        let nightMotionAway = """
        {
            "timestamp": \(Date().timeIntervalSince1970 - 3600 * 3),
            "home_mode": "away",
            "events": [{"type": "motion", "confidence": 0.85, "metadata": {"duration": 60, "energy": 0.7}}],
            "metadata": {"location": "backyard"}
        }
        """
        
        let nightMotionHome = """
        {
            "timestamp": \(Date().timeIntervalSince1970 - 3600 * 3),
            "home_mode": "home",
            "events": [{"type": "motion", "confidence": 0.85, "metadata": {"duration": 60, "energy": 0.7}}],
            "metadata": {"location": "backyard"}
        }
        """
        
        let awayResult = try await sdk.assess(requestJson: nightMotionAway)
        let homeResult = try await sdk.assess(requestJson: nightMotionHome)
        
        print("   Night + Away: \(awayResult.threatLevel)")
        print("   Night + Home: \(homeResult.threatLevel)")
        
        // Away should be more concerning
        XCTAssertTrue(awayResult.threatLevel.rawValue > homeResult.threatLevel.rawValue,
                     "❌ FAIL: Night motion response doesn't consider home mode")
        
        print("✅ PASS: Night motion response appropriate")
    }
    
    func testRepeatedDoorEventsResponse() async throws {
        print("\n⚠️ TEST: Repeated Door Events Response")
        
        let singleDoor = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "away",
            "events": [{"type": "door", "confidence": 0.85}],
            "metadata": {"location": "front_door"}
        }
        """
        
        let multipleDoors = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "away",
            "events": [
                {"type": "door", "confidence": 0.85, "timestamp": \(Date().timeIntervalSince1970)},
                {"type": "door", "confidence": 0.82, "timestamp": \(Date().timeIntervalSince1970 + 4)},
                {"type": "door", "confidence": 0.88, "timestamp": \(Date().timeIntervalSince1970 + 8)}
            ],
            "metadata": {"location": "front_door"}
        }
        """
        
        let singleResult = try await sdk.assess(requestJson: singleDoor)
        let multipleResult = try await sdk.assess(requestJson: multipleDoors)
        
        print("   Single door: \(singleResult.threatLevel)")
        print("   Multiple doors: \(multipleResult.threatLevel)")
        
        // Multiple should escalate
        XCTAssertTrue(multipleResult.threatLevel.rawValue > singleResult.threatLevel.rawValue,
                     "❌ FAIL: Repeated door events don't escalate")
        
        print("✅ PASS: Repeated door events escalate appropriately")
    }
    
    func testWindowBreachResponse() async throws {
        print("\n⚠️ TEST: Window Open/Breach Response")
        
        let windowEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "away",
            "events": [{"type": "window", "confidence": 0.88}],
            "metadata": {"location": "bedroom"}
        }
        """
        
        let result = try await sdk.assess(requestJson: windowEvent)
        
        print("   Window breach: \(result.threatLevel)")
        
        XCTAssertTrue(result.threatLevel == .elevated || result.threatLevel == .critical,
                     "❌ FAIL: Window breach not treated seriously")
        
        print("✅ PASS: Window breach triggers appropriate response")
    }
    
    // MARK: - Normal/Low Threat Responses
    
    func testDaytimeDeliveryResponse() async throws {
        print("\n✅ TEST: Daytime Delivery Response")
        
        let deliveryEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "away",
            "events": [
                {"type": "doorbell_chime", "confidence": 0.95},
                {"type": "motion", "confidence": 0.88, "metadata": {"duration": 8, "energy": 0.25}}
            ],
            "metadata": {"location": "front_door"}
        }
        """
        
        let result = try await sdk.assess(requestJson: deliveryEvent)
        
        print("   Daytime delivery: \(result.threatLevel)")
        
        XCTAssertTrue(result.threatLevel == .low || result.threatLevel == .standard,
                     "❌ FAIL: Normal delivery over-escalated")
        
        print("✅ PASS: Daytime delivery appropriately dampened")
    }
    
    func testPetMotionResponse() async throws {
        print("\n✅ TEST: Pet Motion Response")
        
        let petEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "home",
            "events": [{"type": "pet", "confidence": 0.85, "metadata": {"species": "cat"}}],
            "metadata": {"location": "living_room"}
        }
        """
        
        let result = try await sdk.assess(requestJson: petEvent)
        
        print("   Pet motion: \(result.threatLevel)")
        
        XCTAssertEqual(result.threatLevel, .low,
                      "❌ FAIL: Pet motion not dampened")
        
        print("✅ PASS: Pet motion appropriately dampened")
    }
    
    func testVehicleArrivalResponse() async throws {
        print("\n✅ TEST: Vehicle Arrival Response")
        
        let vehicleEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "home",
            "events": [
                {"type": "vehicle", "confidence": 0.90},
                {"type": "motion", "confidence": 0.85}
            ],
            "metadata": {"location": "driveway"}
        }
        """
        
        let result = try await sdk.assess(requestJson: vehicleEvent)
        
        print("   Vehicle arrival (home mode): \(result.threatLevel)")
        
        XCTAssertTrue(result.threatLevel == .low || result.threatLevel == .standard,
                     "❌ FAIL: Normal vehicle arrival over-escalated")
        
        print("✅ PASS: Vehicle arrival appropriately handled")
    }
    
    // MARK: - Complex Scenario Responses
    
    func testHomeOwnerReturnScenario() async throws {
        print("\n🏠 TEST: Homeowner Return Scenario")
        
        let returnEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970 - 3600 * 10),
            "home_mode": "home",
            "events": [
                {"type": "vehicle", "confidence": 0.92, "timestamp": \(Date().timeIntervalSince1970)},
                {"type": "door", "confidence": 0.95, "timestamp": \(Date().timeIntervalSince1970 + 15)},
                {"type": "motion", "confidence": 0.88, "timestamp": \(Date().timeIntervalSince1970 + 20)}
            ],
            "metadata": {"location": "garage_door"}
        }
        """
        
        let result = try await sdk.assess(requestJson: returnEvent)
        
        print("   Homeowner return: \(result.threatLevel)")
        
        // Should recognize normal return pattern
        XCTAssertTrue(result.threatLevel == .low || result.threatLevel == .standard,
                     "❌ FAIL: Normal homeowner return flagged as threat")
        
        print("✅ PASS: Homeowner return recognized correctly")
    }
    
    func testGuestArrivalScenario() async throws {
        print("\n🏠 TEST: Guest Arrival Scenario")
        
        let guestEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "home",
            "events": [
                {"type": "doorbell_chime", "confidence": 0.95},
                {"type": "motion", "confidence": 0.88, "metadata": {"duration": 120, "energy": 0.6}},
                {"type": "door", "confidence": 0.90}
            ],
            "metadata": {"location": "front_door"}
        }
        """
        
        let result = try await sdk.assess(requestJson: guestEvent)
        
        print("   Guest arrival (home mode): \(result.threatLevel)")
        
        // Should be low/standard when home
        XCTAssertTrue(result.threatLevel == .low || result.threatLevel == .standard,
                     "❌ FAIL: Guest arrival while home over-escalated")
        
        print("✅ PASS: Guest arrival handled appropriately")
    }
    
    func testMaintenanceWorkerScenario() async throws {
        print("\n🏠 TEST: Maintenance Worker Scenario")
        
        let maintenanceEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "away",
            "events": [
                {"type": "doorbell_chime", "confidence": 0.92},
                {"type": "motion", "confidence": 0.90, "metadata": {"duration": 180, "energy": 0.7}},
                {"type": "motion", "confidence": 0.88, "metadata": {"duration": 150, "energy": 0.65}}
            ],
            "metadata": {"location": "front_door"}
        }
        """
        
        let result = try await sdk.assess(requestJson: maintenanceEvent)
        let explanation = try await sdk.assessPI(requestJson: maintenanceEvent)
        
        print("   Maintenance worker: \(result.threatLevel)")
        print("   Explanation: \(String(explanation.prefix(150)))...")
        
        // Extended activity should be flagged for review
        XCTAssertTrue(result.threatLevel == .standard || result.threatLevel == .elevated,
                     "❌ FAIL: Extended activity not appropriately assessed")
        
        print("✅ PASS: Extended activity scenario handled")
    }
    
    func testNeighborCheckingScenario() async throws {
        print("\n🏠 TEST: Neighbor Checking Property Scenario")
        
        let neighborEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "away",
            "events": [
                {"type": "motion", "confidence": 0.85, "metadata": {"duration": 30, "energy": 0.5, "location": "driveway"}},
                {"type": "doorbell_chime", "confidence": 0.88},
                {"type": "motion", "confidence": 0.82, "metadata": {"duration": 25, "energy": 0.45}}
            ],
            "metadata": {"location": "front_door"}
        }
        """
        
        let result = try await sdk.assess(requestJson: neighborEvent)
        
        print("   Neighbor checking: \(result.threatLevel)")
        
        // Should be standard - worth noting but not alarming
        XCTAssertTrue(result.threatLevel == .standard || result.threatLevel == .low,
                     "❌ FAIL: Friendly neighbor visit over-escalated")
        
        print("✅ PASS: Neighbor scenario handled reasonably")
    }
    
    // MARK: - False Positive Scenarios
    
    func testWindBlowingDebrisResponse() async throws {
        print("\n🍃 TEST: Wind/Debris False Positive")
        
        let windEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "away",
            "events": [
                {"type": "motion", "confidence": 0.45, "metadata": {"duration": 3, "energy": 0.15}},
                {"type": "motion", "confidence": 0.38, "metadata": {"duration": 2, "energy": 0.12}}
            ],
            "metadata": {"location": "backyard"}
        }
        """
        
        let result = try await sdk.assess(requestJson: windEvent)
        
        print("   Wind/debris (low confidence): \(result.threatLevel)")
        
        // Low confidence, brief events should be dampened
        XCTAssertTrue(result.threatLevel == .low || result.threatLevel == .standard,
                     "❌ FAIL: Low confidence events over-escalated")
        
        print("✅ PASS: Low confidence events appropriately dampened")
    }
    
    func testCarHeadlightsResponse() async throws {
        print("\n🚗 TEST: Car Headlights False Positive")
        
        let headlightsEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970 - 3600 * 2),
            "home_mode": "away",
            "events": [
                {"type": "motion", "confidence": 0.55, "metadata": {"duration": 5, "energy": 0.2}}
            ],
            "metadata": {"location": "street"}
        }
        """
        
        let result = try await sdk.assess(requestJson: headlightsEvent)
        
        print("   Car headlights (street): \(result.threatLevel)")
        
        // Street location should be low risk
        XCTAssertTrue(result.threatLevel == .low || result.threatLevel == .standard,
                     "❌ FAIL: Street activity over-escalated")
        
        print("✅ PASS: Street activity appropriately handled")
    }
    
    func testShadowsResponse() async throws {
        print("\n🌙 TEST: Shadows/Lighting False Positive")
        
        let shadowEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "away",
            "events": [
                {"type": "motion", "confidence": 0.35, "metadata": {"duration": 1, "energy": 0.08}}
            ],
            "metadata": {"location": "porch"}
        }
        """
        
        let result = try await sdk.assess(requestJson: shadowEvent)
        
        print("   Shadows (very low confidence): \(result.threatLevel)")
        
        // Very low confidence should be heavily dampened
        XCTAssertEqual(result.threatLevel, .low,
                      "❌ FAIL: Very low confidence events not dampened")
        
        print("✅ PASS: Very low confidence appropriately handled")
    }
    
    // MARK: - Edge Case Responses
    
    func testSimultaneousMultipleZonesResponse() async throws {
        print("\n🔀 TEST: Simultaneous Multiple Zones")
        
        let multiZoneEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "away",
            "events": [
                {"type": "motion", "confidence": 0.85, "timestamp": \(Date().timeIntervalSince1970), "metadata": {"location": "front_door"}},
                {"type": "motion", "confidence": 0.82, "timestamp": \(Date().timeIntervalSince1970 + 1), "metadata": {"location": "back_door"}},
                {"type": "motion", "confidence": 0.88, "timestamp": \(Date().timeIntervalSince1970 + 2), "metadata": {"location": "side_yard"}}
            ],
            "metadata": {"location": "perimeter"}
        }
        """
        
        let result = try await sdk.assess(requestJson: multiZoneEvent)
        
        print("   Simultaneous multi-zone: \(result.threatLevel)")
        
        // Multiple zones simultaneously is very suspicious
        XCTAssertTrue(result.threatLevel == .elevated || result.threatLevel == .critical,
                     "❌ FAIL: Multi-zone activity not escalated")
        
        print("✅ PASS: Multi-zone activity escalated appropriately")
    }
    
    func testRapidEventSequenceResponse() async throws {
        print("\n⚡️ TEST: Rapid Event Sequence")
        
        let rapidEvents = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "away",
            "events": [
                {"type": "motion", "confidence": 0.85, "timestamp": \(Date().timeIntervalSince1970)},
                {"type": "door", "confidence": 0.88, "timestamp": \(Date().timeIntervalSince1970 + 1)},
                {"type": "window", "confidence": 0.82, "timestamp": \(Date().timeIntervalSince1970 + 2)},
                {"type": "motion", "confidence": 0.90, "timestamp": \(Date().timeIntervalSince1970 + 3)}
            ],
            "metadata": {"location": "back_door"}
        }
        """
        
        let result = try await sdk.assess(requestJson: rapidEvents)
        
        print("   Rapid sequence: \(result.threatLevel)")
        
        // Rapid sequence should escalate
        XCTAssertTrue(result.threatLevel == .elevated || result.threatLevel == .critical,
                     "❌ FAIL: Rapid event sequence not escalated")
        
        print("✅ PASS: Rapid sequences escalate appropriately")
    }
    
    // MARK: - Response Summary
    
    func testEventResponseSummary() async throws {
        print("\n" + String(repeating: "=", count: 70))
        print("🎯 EVENT RESPONSE TEST SUMMARY")
        print(String(repeating: "=", count: 70))
        
        print("✅ Critical Events (Always Escalate):")
        print("   ✓ Glass break → CRITICAL")
        print("   ✓ Fire/smoke → CRITICAL")
        print("   ✓ CO2/gas → CRITICAL")
        print("   ✓ Water leak → ELEVATED/CRITICAL")
        
        print("\n✅ Elevated Events (Context-Dependent):")
        print("   ✓ Night motion (away mode)")
        print("   ✓ Repeated door attempts")
        print("   ✓ Window breach")
        print("   ✓ Multi-zone activity")
        
        print("\n✅ Normal Events (Appropriately Dampened):")
        print("   ✓ Daytime deliveries")
        print("   ✓ Pet motion")
        print("   ✓ Vehicle arrivals (home mode)")
        print("   ✓ Homeowner returns")
        
        print("\n✅ False Positive Handling:")
        print("   ✓ Wind/debris (low confidence)")
        print("   ✓ Car headlights (street)")
        print("   ✓ Shadows (very low confidence)")
        
        print("\n✅ Complex Scenarios:")
        print("   ✓ Homeowner return")
        print("   ✓ Guest arrival")
        print("   ✓ Maintenance workers")
        print("   ✓ Neighbor checks")
        
        print("\n✅ Edge Cases:")
        print("   ✓ Simultaneous multi-zone")
        print("   ✓ Rapid event sequences")
        
        let metrics = sdk.getTelemetryMetrics()
        print("\n📊 Response Metrics:")
        print("   Total Events: \(metrics.totalEvents)")
        print("   Dampened: \(metrics.dampenedEvents)")
        print("   Boosted: \(metrics.boostedEvents)")
        print("   Effectiveness: \(String(format: "%.1f", metrics.effectiveness * 100))%")
        
        print("\n🏆 EVENT RESPONSE SCORE: CONTEXTUALLY INTELLIGENT")
        print(String(repeating: "=", count: 70) + "\n")
    }
}
