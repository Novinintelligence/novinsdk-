import XCTest
import NovinIntelligence

@available(iOS 15.0, *)
final class BrandIntegrationTests: XCTestCase {
    
    var sdk: NovinIntelligence!
    
    override func setUp() async throws {
        sdk = NovinIntelligence.shared
        try await sdk.initialize()
        sdk.setSystemMode("standard")
    }
    
    // MARK: - Real Brand Event Scenarios
    
    func testRingDoorbellMotionEvent() async throws {
        // Simulate Ring doorbell motion detection
        let ringEvent = """
        {
            "type": "motion",
            "confidence": 0.85,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "front_door",
                "sensor_type": "doorbell_camera",
                "brand": "ring",
                "device_id": "ring_doorbell_001",
                "home_mode": "away"
            },
            "user_context": {
                "user_id": "user_123",
                "home_id": "home_456",
                "subscription_tier": "pro"
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: ringEvent)
        print("RING_DOORBELL_MOTION_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
        XCTAssertTrue(pi.contains("motion"))
    }
    
    func testArloCameraGlassbreakEvent() async throws {
        // Simulate Arlo camera glass break detection
        let arloEvent = """
        {
            "type": "glassbreak",
            "confidence": 0.92,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "living_room",
                "sensor_type": "security_camera",
                "brand": "arlo",
                "device_id": "arlo_cam_002",
                "home_mode": "away",
                "night_vision": true
            },
            "audio_analysis": {
                "frequency_range": "high",
                "duration_ms": 150,
                "decibel_level": 85
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: arloEvent)
        print("ARLO_GLASSBREAK_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
        XCTAssertTrue(pi.contains("glassbreak"))
    }
    
    func testNestThermostatMotionEvent() async throws {
        // Simulate Nest thermostat motion detection
        let nestEvent = """
        {
            "type": "motion",
            "confidence": 0.65,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "hallway",
                "sensor_type": "thermostat",
                "brand": "nest",
                "device_id": "nest_thermostat_003",
                "home_mode": "home",
                "temperature": 72.5
            },
            "occupancy": {
                "detected": true,
                "confidence": 0.65,
                "person_count": 1
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: nestEvent)
        print("NEST_THERMOSTAT_MOTION_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
        XCTAssertTrue(pi.contains("motion"))
    }
    
    func testWyzeDoorSensorEvent() async throws {
        // Simulate Wyze door sensor opening
        let wyzeEvent = """
        {
            "type": "door",
            "confidence": 0.98,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "garage_door",
                "sensor_type": "contact_sensor",
                "brand": "wyze",
                "device_id": "wyze_door_004",
                "home_mode": "away",
                "battery_level": 85
            },
            "door_state": {
                "is_open": true,
                "previous_state": "closed",
                "time_closed_minutes": 45
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: wyzeEvent)
        print("WYZE_DOOR_SENSOR_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
        XCTAssertTrue(pi.contains("door"))
    }
    
    func testEufyPetDetectionEvent() async throws {
        // Simulate Eufy pet detection
        let eufyEvent = """
        {
            "type": "pet",
            "confidence": 0.88,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "living_room",
                "sensor_type": "security_camera",
                "brand": "eufy",
                "device_id": "eufy_cam_005",
                "home_mode": "home",
                "ai_detection": true
            },
            "pet_analysis": {
                "species": "dog",
                "size": "medium",
                "movement_speed": "slow",
                "familiar_pet": true
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: eufyEvent)
        print("EUFY_PET_DETECTION_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
        XCTAssertTrue(pi.contains("pet"))
    }
    
    func testSimpliSafeSoundEvent() async throws {
        // Simulate SimpliSafe sound detection
        let simplisafeEvent = """
        {
            "type": "sound",
            "confidence": 0.75,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "kitchen",
                "sensor_type": "audio_sensor",
                "brand": "simplisafe",
                "device_id": "simplisafe_audio_006",
                "home_mode": "home",
                "volume_threshold": 70
            },
            "audio_analysis": {
                "sound_type": "glass_breaking",
                "frequency_analysis": "high_frequency",
                "duration_ms": 200,
                "decibel_level": 78
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: simplisafeEvent)
        print("SIMPLISAFE_SOUND_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
        XCTAssertTrue(pi.contains("sound"))
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testMalformedJSONEvent() async throws {
        // Test malformed JSON handling
        let malformedEvent = """
        {
            "type": "motion",
            "confidence": 0.8,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "front_door",
                "sensor_type": "doorbell_camera",
                "brand": "ring",
                "device_id": "ring_doorbell_001",
                "home_mode": "away"
            },
            "user_context": {
                "user_id": "user_123",
                "home_id": "home_456",
                "subscription_tier": "pro"
            }
            // Missing closing brace - malformed JSON
        """
        
        // Should handle gracefully without crashing
        do {
            let pi = try await sdk.assessPI(requestJson: malformedEvent)
            print("MALFORMED_JSON_PI:\n\(pi)")
            XCTAssertTrue(pi.contains("security_assessment"))
        } catch {
            // Expected to handle gracefully
            print("Malformed JSON handled gracefully: \(error)")
        }
    }
    
    func testMissingRequiredFields() async throws {
        // Test missing required fields
        let incompleteEvent = """
        {
            "type": "motion",
            "timestamp": \(Date().timeIntervalSince1970)
            // Missing confidence, metadata, etc.
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: incompleteEvent)
        print("INCOMPLETE_EVENT_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
    }
    
    func testExtremeConfidenceValues() async throws {
        // Test extreme confidence values
        let extremeEvent = """
        {
            "type": "motion",
            "confidence": 1.5,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "front_door",
                "sensor_type": "doorbell_camera",
                "brand": "ring",
                "device_id": "ring_doorbell_001",
                "home_mode": "away"
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: extremeEvent)
        print("EXTREME_CONFIDENCE_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
    }
    
    func testNegativeTimestamp() async throws {
        // Test negative timestamp
        let negativeTimeEvent = """
        {
            "type": "motion",
            "confidence": 0.8,
            "timestamp": -1000,
            "metadata": {
                "location": "front_door",
                "sensor_type": "doorbell_camera",
                "brand": "ring",
                "device_id": "ring_doorbell_001",
                "home_mode": "away"
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: negativeTimeEvent)
        print("NEGATIVE_TIMESTAMP_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
    }
    
    func testUnknownEventType() async throws {
        // Test unknown event type
        let unknownEvent = """
        {
            "type": "unknown_sensor_type",
            "confidence": 0.8,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "front_door",
                "sensor_type": "custom_sensor",
                "brand": "custom_brand",
                "device_id": "custom_device_007",
                "home_mode": "away"
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: unknownEvent)
        print("UNKNOWN_EVENT_TYPE_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
    }
    
    // MARK: - High-Volume Testing
    
    func testRapidEventSequence() async throws {
        // Test rapid sequence of events (like real brand integration)
        let events = [
            ("motion", 0.8, "front_door"),
            ("door", 0.9, "garage_door"),
            ("motion", 0.7, "living_room"),
            ("sound", 0.6, "kitchen"),
            ("motion", 0.85, "hallway")
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
                    "sensor_type": "security_sensor",
                    "brand": "test_brand",
                    "device_id": "test_device_\(type)_\(location)",
                    "home_mode": "away"
                }
            }
            """
            
            let pi = try await sdk.assessPI(requestJson: event)
            results.append(pi)
            
            // Small delay to simulate real-world timing
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        print("RAPID_EVENT_SEQUENCE_RESULTS:")
        for (index, result) in results.enumerated() {
            print("Event \(index + 1): \(result)")
        }
        
        XCTAssertEqual(results.count, 5)
    }
    
    func testConcurrentEventProcessing() async throws {
        // Test concurrent event processing (like multiple brand integrations)
        let event1 = """
        {
            "type": "motion",
            "confidence": 0.8,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "front_door",
                "sensor_type": "doorbell_camera",
                "brand": "ring",
                "device_id": "ring_doorbell_001",
                "home_mode": "away"
            }
        }
        """
        
        let event2 = """
        {
            "type": "glassbreak",
            "confidence": 0.9,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "living_room",
                "sensor_type": "security_camera",
                "brand": "arlo",
                "device_id": "arlo_cam_002",
                "home_mode": "away"
            }
        }
        """
        
        let event3 = """
        {
            "type": "pet",
            "confidence": 0.7,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "kitchen",
                "sensor_type": "security_camera",
                "brand": "eufy",
                "device_id": "eufy_cam_003",
                "home_mode": "home"
            }
        }
        """
        
        // Process events concurrently
        async let result1 = sdk.assessPI(requestJson: event1)
        async let result2 = sdk.assessPI(requestJson: event2)
        async let result3 = sdk.assessPI(requestJson: event3)
        
        let (pi1, pi2, pi3) = try await (result1, result2, result3)
        
        print("CONCURRENT_EVENT_1_PI:\n\(pi1)")
        print("CONCURRENT_EVENT_2_PI:\n\(pi2)")
        print("CONCURRENT_EVENT_3_PI:\n\(pi3)")
        
        XCTAssertTrue(pi1.contains("security_assessment"))
        XCTAssertTrue(pi2.contains("security_assessment"))
        XCTAssertTrue(pi3.contains("security_assessment"))
    }
}


