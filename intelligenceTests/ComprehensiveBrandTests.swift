import XCTest
import NovinIntelligence

@available(iOS 15.0, *)
final class ComprehensiveBrandTests: XCTestCase {
    
    var sdk: NovinIntelligence!
    
    override func setUp() async throws {
        sdk = NovinIntelligence.shared
        try await sdk.initialize()
        sdk.setSystemMode("standard")
    }
    
    // MARK: - Ring Comprehensive Integration Tests
    
    func testRingDoorbellChimePlusMotionEvent() async throws {
        // Real Ring API structure: doorbell chime + motion detection with zones
        let ringComprehensiveEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "away",
            "events": [
                {
                    "type": "doorbell_chime",
                    "confidence": 1.0,
                    "device_id": "ring_doorbell_front",
                    "location": "front_door",
                    "battery_level": 85,
                    "ring_event_kind": "ding",
                    "ring_created_at": "2025-09-29T20:15:00Z",
                    "ring_device_type": "doorbell_v4"
                },
                {
                    "type": "motion",
                    "confidence": 0.92,
                    "device_id": "ring_cam_front",
                    "location": "front_yard",
                    "zones": ["driveway", "front_porch"],
                    "ring_event_kind": "motion",
                    "ring_activity_zones": ["driveway"],
                    "ring_motion_score": 0.92,
                    "ring_snapshot_url": "https://api.ring.com/clients_api/doorbots/12345/snapshot"
                }
            ],
            "crime_context": {
                "crime_rate_24h": 0.35,
                "neighborhood_alerts": 2,
                "ring_community_alerts": 2,
                "ring_neighborhood_crime": "moderate"
            },
            "brand_metadata": {
                "source": "ring",
                "api_version": "v1",
                "event_source": "ring_client_api",
                "home_id": "ring_home_12345"
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: ringComprehensiveEvent)
        print("RING_DOORBELL_CHIME_MOTION_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
        XCTAssertTrue(pi.contains("critical") || pi.contains("standard") || pi.contains("low"))
    }
    
    func testRingMultiCameraMotionEvent() async throws {
        // Ring multiple camera motion detection (real-world scenario)
        let ringMultiCameraEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "away",
            "events": [
                {
                    "type": "motion",
                    "confidence": 0.88,
                    "device_id": "ring_cam_backyard",
                    "location": "backyard",
                    "zones": ["patio", "garden"],
                    "ring_event_kind": "motion",
                    "ring_activity_zones": ["patio"],
                    "ring_motion_score": 0.88,
                    "ring_night_vision": true
                },
                {
                    "type": "motion",
                    "confidence": 0.75,
                    "device_id": "ring_cam_side",
                    "location": "side_yard",
                    "zones": ["sidewalk", "gate"],
                    "ring_event_kind": "motion",
                    "ring_activity_zones": ["sidewalk"],
                    "ring_motion_score": 0.75,
                    "ring_night_vision": false
                }
            ],
            "crime_context": {
                "crime_rate_24h": 0.28,
                "neighborhood_alerts": 1,
                "ring_community_alerts": 1,
                "ring_neighborhood_crime": "low"
            },
            "brand_metadata": {
                "source": "ring",
                "api_version": "v1",
                "event_source": "ring_client_api",
                "home_id": "ring_home_12345"
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: ringMultiCameraEvent)
        print("RING_MULTI_CAMERA_MOTION_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
    }
    
    // MARK: - ADT Comprehensive Integration Tests
    
    func testADTDoorWindowPlusCOEvent() async throws {
        // Real ADT Pulse API structure: window breach + CO detection
        let adtComprehensiveEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "home",
            "events": [
                {
                    "type": "doorWindow",
                    "confidence": 1.0,
                    "device_id": "adt_window_family_room",
                    "zone": 99,
                    "status": "open",
                    "adt_sensor_type": "doorWindow",
                    "adt_zone_name": "Family Room Window",
                    "adt_zone_type": "window",
                    "adt_arm_mode": "armed_stay",
                    "adt_sensor_battery": 78
                },
                {
                    "type": "co",
                    "confidence": 0.95,
                    "device_id": "adt_co_kitchen",
                    "zone": 45,
                    "level_ppm": 50,
                    "adt_sensor_type": "co",
                    "adt_zone_name": "Kitchen CO Detector",
                    "adt_zone_type": "co",
                    "adt_arm_mode": "armed_stay",
                    "adt_sensor_battery": 92
                }
            ],
            "crime_context": {
                "crime_rate_24h": 0.28,
                "system_status": "armed_stay",
                "adt_panel_status": "armed_stay",
                "adt_arm_mode": "armed_stay",
                "adt_system_health": "good"
            },
            "brand_metadata": {
                "source": "adt",
                "api_version": "v1",
                "event_source": "adt_pulse_api",
                "home_id": "adt_home_67890"
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: adtComprehensiveEvent)
        print("ADT_DOOR_WINDOW_CO_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
        XCTAssertTrue(pi.contains("doorWindow") || pi.contains("co"))
    }
    
    func testADTMultiZoneBreachEvent() async throws {
        // ADT multiple zone breach (intrusion scenario)
        let adtMultiZoneEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "away",
            "events": [
                {
                    "type": "doorWindow",
                    "confidence": 1.0,
                    "device_id": "adt_door_front",
                    "zone": 1,
                    "status": "open",
                    "adt_sensor_type": "doorWindow",
                    "adt_zone_name": "Front Door",
                    "adt_zone_type": "door",
                    "adt_arm_mode": "armed_away",
                    "adt_sensor_battery": 85
                },
                {
                    "type": "motion",
                    "confidence": 0.98,
                    "device_id": "adt_motion_living",
                    "zone": 15,
                    "adt_sensor_type": "motion",
                    "adt_zone_name": "Living Room Motion",
                    "adt_zone_type": "motion",
                    "adt_arm_mode": "armed_away",
                    "adt_sensor_battery": 91
                },
                {
                    "type": "glassbreak",
                    "confidence": 0.87,
                    "device_id": "adt_glass_kitchen",
                    "zone": 22,
                    "adt_sensor_type": "glassbreak",
                    "adt_zone_name": "Kitchen Glass Break",
                    "adt_zone_type": "glassbreak",
                    "adt_arm_mode": "armed_away",
                    "adt_sensor_battery": 88
                }
            ],
            "crime_context": {
                "crime_rate_24h": 0.45,
                "system_status": "armed_away",
                "adt_panel_status": "armed_away",
                "adt_arm_mode": "armed_away",
                "adt_system_health": "good"
            },
            "brand_metadata": {
                "source": "adt",
                "api_version": "v1",
                "event_source": "adt_pulse_api",
                "home_id": "adt_home_67890"
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: adtMultiZoneEvent)
        print("ADT_MULTI_ZONE_BREACH_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
    }
    
    // MARK: - Nest Comprehensive Integration Tests
    
    func testNestPersonDetectionPlusTemperatureEvent() async throws {
        // Real Nest SDM API structure: person detection + temperature anomaly
        let nestComprehensiveEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "away",
            "events": [
                {
                    "type": "person",
                    "confidence": 0.97,
                    "device_id": "nest_cam_front",
                    "event_session_id": "CjY5Y3VKaTZwR3o4Y19YbTVfMF...",
                    "zones": ["front_porch"],
                    "event_thread_id": "d67cd3f7-86a7-425e-8bb3-462f92ec9f59",
                    "nest_event_type": "sdm.devices.events.CameraPerson.Person",
                    "nest_trait": "sdm.devices.traits.CameraPerson",
                    "nest_structure_id": "enterprises/project-id/structures/home",
                    "nest_device_name": "Front Door Camera",
                    "nest_activity_zones": ["front_porch"],
                    "nest_person_detection_score": 0.97
                },
                {
                    "type": "temperature",
                    "confidence": 1.0,
                    "device_id": "nest_thermostat_upstairs",
                    "ambient_temperature_celsius": 28.5,
                    "humidity_percent": 65,
                    "nest_event_type": "sdm.devices.events.ThermostatTemperature.Temperature",
                    "nest_trait": "sdm.devices.traits.ThermostatTemperature",
                    "nest_structure_id": "enterprises/project-id/structures/home",
                    "nest_device_name": "Upstairs Thermostat",
                    "nest_target_temperature": 22.0,
                    "nest_hvac_mode": "heat"
                }
            ],
            "crime_context": {
                "crime_rate_24h": 0.42,
                "structure_id": "enterprises/project-id/structures/home",
                "nest_aware_alerts": 3,
                "nest_neighborhood_crime": "moderate"
            },
            "brand_metadata": {
                "source": "nest",
                "api_version": "v1",
                "event_source": "nest_sdm_api",
                "home_id": "nest_home_11111"
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: nestComprehensiveEvent)
        print("NEST_PERSON_TEMPERATURE_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
        XCTAssertTrue(pi.contains("critical") || pi.contains("standard") || pi.contains("low"))
    }
    
    func testNestMultiDeviceEvent() async throws {
        // Nest multiple device event (doorbell + camera + thermostat)
        let nestMultiDeviceEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "home",
            "events": [
                {
                    "type": "doorbell_chime",
                    "confidence": 1.0,
                    "device_id": "nest_doorbell_front",
                    "event_session_id": "CjY5Y3VKaTZwR3o4Y19YbTVfMF...",
                    "zones": ["front_porch"],
                    "nest_event_type": "sdm.devices.events.DoorbellChime.Chime",
                    "nest_trait": "sdm.devices.traits.DoorbellChime",
                    "nest_structure_id": "enterprises/project-id/structures/home",
                    "nest_device_name": "Front Door Doorbell"
                },
                {
                    "type": "motion",
                    "confidence": 0.89,
                    "device_id": "nest_cam_living",
                    "event_session_id": "CjY5Y3VKaTZwR3o4Y19YbTVfMF...",
                    "zones": ["living_room"],
                    "nest_event_type": "sdm.devices.events.CameraMotion.Motion",
                    "nest_trait": "sdm.devices.traits.CameraMotion",
                    "nest_structure_id": "enterprises/project-id/structures/home",
                    "nest_device_name": "Living Room Camera",
                    "nest_motion_score": 0.89
                },
                {
                    "type": "temperature",
                    "confidence": 1.0,
                    "device_id": "nest_thermostat_living",
                    "ambient_temperature_celsius": 24.2,
                    "humidity_percent": 58,
                    "nest_event_type": "sdm.devices.events.ThermostatTemperature.Temperature",
                    "nest_trait": "sdm.devices.traits.ThermostatTemperature",
                    "nest_structure_id": "enterprises/project-id/structures/home",
                    "nest_device_name": "Living Room Thermostat",
                    "nest_target_temperature": 22.0,
                    "nest_hvac_mode": "cool"
                }
            ],
            "crime_context": {
                "crime_rate_24h": 0.31,
                "structure_id": "enterprises/project-id/structures/home",
                "nest_aware_alerts": 1,
                "nest_neighborhood_crime": "low"
            },
            "brand_metadata": {
                "source": "nest",
                "api_version": "v1",
                "event_source": "nest_sdm_api",
                "home_id": "nest_home_11111"
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: nestMultiDeviceEvent)
        print("NEST_MULTI_DEVICE_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
    }
    
    // MARK: - Cross-Brand Integration Tests
    
    func testCrossBrandEventFusion() async throws {
        // Test multiple brands sending events simultaneously (real-world scenario)
        let crossBrandEvent = """
        {
            "timestamp": \(Date().timeIntervalSince1970),
            "home_mode": "away",
            "events": [
                {
                    "type": "motion",
                    "confidence": 0.92,
                    "device_id": "ring_cam_front",
                    "location": "front_yard",
                    "zones": ["driveway"],
                    "brand_metadata": {
                        "source": "ring",
                        "ring_event_kind": "motion",
                        "ring_activity_zones": ["driveway"]
                    }
                },
                {
                    "type": "doorWindow",
                    "confidence": 1.0,
                    "device_id": "adt_door_front",
                    "zone": 1,
                    "status": "open",
                    "brand_metadata": {
                        "source": "adt",
                        "adt_sensor_type": "doorWindow",
                        "adt_zone_name": "Front Door"
                    }
                },
                {
                    "type": "person",
                    "confidence": 0.95,
                    "device_id": "nest_cam_front",
                    "event_session_id": "CjY5Y3VKaTZwR3o4Y19YbTVfMF...",
                    "zones": ["front_porch"],
                    "brand_metadata": {
                        "source": "nest",
                        "nest_event_type": "sdm.devices.events.CameraPerson.Person",
                        "nest_person_detection_score": 0.95
                    }
                }
            ],
            "crime_context": {
                "crime_rate_24h": 0.38,
                "neighborhood_alerts": 2,
                "ring_community_alerts": 1,
                "adt_system_status": "armed_away",
                "nest_aware_alerts": 1
            },
            "brand_metadata": {
                "source": "multi_brand",
                "api_version": "v1",
                "event_source": "cross_brand_fusion",
                "home_id": "multi_brand_home_99999"
            }
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: crossBrandEvent)
        print("CROSS_BRAND_FUSION_PI:\n\(pi)")
        
        XCTAssertTrue(pi.contains("security_assessment"))
    }
    
    // MARK: - High-Volume Real-World Testing
    
    func testHighVolumeBrandEventProcessing() async throws {
        // Simulate high-volume brand event processing (like real production)
        let events = [
            ("ring", "motion", 0.88, "front_yard", ["driveway"]),
            ("adt", "doorWindow", 1.0, "front_door", [1]),
            ("nest", "person", 0.94, "front_porch", ["front_porch"]),
            ("ring", "doorbell_chime", 1.0, "front_door", []),
            ("adt", "motion", 0.91, "living_room", [15]),
            ("nest", "temperature", 1.0, "living_room", []),
            ("ring", "motion", 0.76, "backyard", ["patio"]),
            ("adt", "glassbreak", 0.89, "kitchen", [22]),
            ("nest", "motion", 0.87, "living_room", ["living_room"]),
            ("ring", "motion", 0.82, "side_yard", ["sidewalk"])
        ]
        
        var results: [String] = []
        let startTime = Date()
        
        for (brand, type, confidence, location, zones) in events {
            let event = """
            {
                "timestamp": \(Date().timeIntervalSince1970),
                "home_mode": "away",
                "events": [
                    {
                        "type": "\(type)",
                        "confidence": \(confidence),
                        "device_id": "\(brand)_device_\(location)",
                        "location": "\(location)",
                        "zones": \(zones),
                        "brand_metadata": {
                            "source": "\(brand)",
                            "\(brand)_event_kind": "\(type)",
                            "\(brand)_confidence": \(confidence)
                        }
                    }
                ],
                "crime_context": {
                    "crime_rate_24h": 0.35,
                    "neighborhood_alerts": 2
                },
                "brand_metadata": {
                    "source": "\(brand)",
                    "api_version": "v1",
                    "event_source": "\(brand)_api",
                    "home_id": "\(brand)_home_12345"
                }
            }
            """
            
            let pi = try await sdk.assessPI(requestJson: event)
            results.append(pi)
            
            // Simulate real-world timing
            try await Task.sleep(nanoseconds: 5_000_000) // 5ms
        }
        
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        
        print("HIGH_VOLUME_BRAND_PROCESSING_RESULTS:")
        print("Processed \(events.count) events in \(String(format: "%.3f", totalTime)) seconds")
        print("Average processing time: \(String(format: "%.3f", totalTime / Double(events.count))) seconds per event")
        
        for (index, result) in results.enumerated() {
            print("Event \(index + 1) (\(events[index].0) \(events[index].1)): \(result)")
        }
        
        XCTAssertEqual(results.count, events.count)
        XCTAssertLessThan(totalTime, 1.0) // Should process all events in under 1 second
    }
    
    // MARK: - Error Handling and Edge Cases
    
    func testBrandSpecificErrorHandling() async throws {
        // Test brand-specific error scenarios
        let errorScenarios = [
            ("ring", "Invalid Ring API response format"),
            ("adt", "ADT sensor offline"),
            ("nest", "Nest Pub/Sub connection lost")
        ]
        
        for (brand, errorType) in errorScenarios {
            let errorEvent = """
            {
                "timestamp": \(Date().timeIntervalSince1970),
                "home_mode": "away",
                "events": [
                    {
                        "type": "motion",
                        "confidence": 0.8,
                        "device_id": "\(brand)_device_error",
                        "location": "test_location",
                        "brand_metadata": {
                            "source": "\(brand)",
                            "error_type": "\(errorType)",
                            "error_handled": true
                        }
                    }
                ],
                "crime_context": {
                    "crime_rate_24h": 0.35
                },
                "brand_metadata": {
                    "source": "\(brand)",
                    "api_version": "v1",
                    "event_source": "\(brand)_api_error",
                    "home_id": "\(brand)_home_error"
                }
            }
            """
            
            let pi = try await sdk.assessPI(requestJson: errorEvent)
            print("\(brand.uppercased())_ERROR_HANDLING_PI:\n\(pi)")
            
            XCTAssertTrue(pi.contains("security_assessment"))
        }
    }
}
