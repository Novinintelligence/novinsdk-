import XCTest
import NovinIntelligence

@available(iOS 15.0, *)
final class AdaptabilityTests: XCTestCase {
    
    var sdk: NovinIntelligence!
    
    override func setUp() async throws {
        sdk = NovinIntelligence.shared
        try await sdk.initialize()
        sdk.setSystemMode("standard")
    }
    
    func testUnknownEventTypeAdaptation() async throws {
        // Test completely unknown event type
        let unknownEvent = """
        {
            "type": "drone_detection",
            "confidence": 0.85,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "backyard",
                "altitude": 50,
                "speed": 25,
                "home_mode": "away"
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: unknownEvent)
        print("UNKNOWN_DRONE_EVENT_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
    }
    
    func testCustomSensorEvent() async throws {
        // Test custom sensor event
        let customEvent = """
        {
            "type": "water_leak_detector",
            "confidence": 0.92,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "basement",
                "water_level": 0.8,
                "home_mode": "home"
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: customEvent)
        print("CUSTOM_WATER_LEAK_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
    }
    
    func testFutureTechEvent() async throws {
        // Test future technology event
        let futureEvent = """
        {
            "type": "ai_behavior_anomaly",
            "confidence": 0.78,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "living_room",
                "anomaly_score": 0.85,
                "home_mode": "away"
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: futureEvent)
        print("FUTURE_AI_ANOMALY_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
    }
    
    func testMixedUnknownEvents() async throws {
        // Test multiple unknown event types
        let events = [
            ("smart_mirror_intrusion", 0.9, "bathroom"),
            ("garage_door_anomaly", 0.7, "garage"),
            ("pool_sensor_breach", 0.8, "backyard"),
            ("smart_fridge_tamper", 0.6, "kitchen"),
            ("hvac_system_hack", 0.95, "basement")
        ]
        
        var results: [String] = []
        
        for (type, confidence, location) in events {
            let event = """
            {
                "type": "\(type)",
                "confidence": \(confidence),
                "timestamp": \(Date().timeIntervalSince1970),
                "metadata": {
                    "location": "\(location)",
                    "home_mode": "away"
                }
            }
            """
            
            let pi = try await sdk.assessPI(requestJson: event)
            results.append(pi)
            
            try await Task.sleep(nanoseconds: 5_000_000) // 5ms
        }
        
        print("MIXED_UNKNOWN_EVENTS_RESULTS:")
        for (index, result) in results.enumerated() {
            print("Event \(index + 1) (\(events[index].0)): \(result)")
        }
        
        XCTAssertEqual(results.count, events.count)
    }
}

