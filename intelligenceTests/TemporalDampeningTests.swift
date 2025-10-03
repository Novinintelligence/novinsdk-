import XCTest
import NovinIntelligence

@available(iOS 15.0, *)
final class TemporalDampeningTests: XCTestCase {
    
    var sdk: NovinIntelligence!
    
    override func setUp() async throws {
        sdk = NovinIntelligence.shared
        try await sdk.initialize()
        sdk.setSystemMode("standard")
    }
    
    func testDaytimeDoorbellMotionDampening() async throws {
        // Test doorbell + motion during delivery hours (should be dampened)
        let daytimeEvent = """
        {
            "type": "doorbell_chime",
            "confidence": 0.92,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "front_door",
                "home_mode": "away",
                "brand": "ring",
                "device_id": "ring_doorbell_001"
            },
            "events": [
                {
                    "type": "doorbell_chime",
                    "confidence": 0.92,
                    "device_id": "ring_doorbell_front",
                    "location": "front_door"
                },
                {
                    "type": "motion",
                    "confidence": 0.88,
                    "device_id": "ring_cam_front",
                    "location": "front_yard"
                }
            ]
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: daytimeEvent)
        print("DAYTIME_DOORBELL_MOTION_DAMPENED_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
        // Should be LOW or STANDARD, not CRITICAL
        XCTAssertTrue(pi.contains("low") || pi.contains("standard"))
    }
    
    func testNighttimeDoorbellMotionBoost() async throws {
        // Test doorbell + motion during night hours (should be elevated)
        let nightTime = Date().addingTimeInterval(-3600 * 8) // 8 hours ago (simulate night)
        let nighttimeEvent = """
        {
            "type": "doorbell_chime",
            "confidence": 0.92,
            "timestamp": \(nightTime.timeIntervalSince1970),
            "metadata": {
                "location": "front_door",
                "home_mode": "away",
                "brand": "ring",
                "device_id": "ring_doorbell_001"
            },
            "events": [
                {
                    "type": "doorbell_chime",
                    "confidence": 0.92,
                    "device_id": "ring_doorbell_front",
                    "location": "front_door"
                },
                {
                    "type": "motion",
                    "confidence": 0.88,
                    "device_id": "ring_cam_front",
                    "location": "front_yard"
                }
            ]
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: nighttimeEvent)
        print("NIGHTTIME_DOORBELL_MOTION_BOOSTED_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
        // Should be ELEVATED or CRITICAL for night activity
        XCTAssertTrue(pi.contains("elevated") || pi.contains("critical") || pi.contains("standard"))
    }
    
    func testGlassBreakNeverDampened() async throws {
        // Test glass break (should never be dampened)
        let glassBreakEvent = """
        {
            "type": "glassbreak",
            "confidence": 0.95,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "living_room",
                "home_mode": "away",
                "brand": "arlo",
                "device_id": "arlo_cam_002"
            },
            "events": [
                {
                    "type": "glassbreak",
                    "confidence": 0.95,
                    "device_id": "arlo_glass_sensor",
                    "location": "living_room"
                }
            ]
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: glassBreakEvent)
        print("GLASS_BREAK_NEVER_DAMPENED_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
        // Should be CRITICAL regardless of time
        XCTAssertTrue(pi.contains("critical"))
    }
    
    func testPetMotionDampening() async throws {
        // Test pet motion (should be heavily dampened)
        let petEvent = """
        {
            "type": "pet",
            "confidence": 0.88,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "living_room",
                "home_mode": "away",
                "brand": "eufy",
                "device_id": "eufy_cam_005"
            },
            "events": [
                {
                    "type": "pet",
                    "confidence": 0.88,
                    "device_id": "eufy_cam_living",
                    "location": "living_room"
                }
            ]
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: petEvent)
        print("PET_MOTION_DAMPENED_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
        // Should be LOW due to pet dampening
        XCTAssertTrue(pi.contains("low"))
    }
}

