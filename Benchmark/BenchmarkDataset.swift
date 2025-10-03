// BenchmarkDataset.swift - Fat Benchmark Dataset Generator
// Generates 10,000+ realistic scenarios to stress-test NovinIntelligence SDK

import Foundation

// MARK: - Ground Truth Labels
enum GroundTruth: String, Codable {
    case safe           // No threat (delivery, normal activity)
    case low            // Minor concern (unknown person, off-hours activity)
    case elevated       // Suspicious (loitering, repeated attempts)
    case critical       // Real threat (break-in, intrusion)
}

// MARK: - Scenario Categories
enum ScenarioCategory: String, CaseIterable {
    case delivery           // Amazon/FedEx/UPS delivery
    case burglar            // Active break-in attempt
    case prowler            // Suspicious loitering
    case pet                // Pet motion (should NOT alert)
    case falseAlarm         // Environmental (wind, animals)
    case packageTheft       // Porch pirate
    case familyActivity     // Normal home activity
    case neighbor           // Neighbor activity (boundary)
    case maintenance        // Gardener, cleaner, etc.
    case emergency          // Fire, medical, police
}

// MARK: - Difficulty Levels
enum Difficulty: String {
    case easy       // Obvious classification
    case medium     // Requires context
    case hard       // Ambiguous, needs AI
    case edgeCase   // Stress test
}

// MARK: - Benchmark Scenario
struct BenchmarkScenario: Codable {
    let id: String
    let category: ScenarioCategory
    let difficulty: Difficulty
    let groundTruth: GroundTruth
    let description: String
    let events: [String]  // Array of JSON event strings
    let timeOfDay: Int    // Hour (0-23)
    let homeMode: String  // "home" or "away"
    let expectedProcessingTime: Double  // Max ms allowed
}

// MARK: - Dataset Generator
struct BenchmarkDataset {
    
    // MARK: - Generate Full Dataset
    static func generate(count: Int = 10000) -> [BenchmarkScenario] {
        var scenarios: [BenchmarkScenario] = []
        
        // Distribution (realistic mix)
        let distribution: [(ScenarioCategory, Int, Difficulty)] = [
            (.delivery, 2500, .easy),           // 25% - Most common
            (.delivery, 500, .medium),          // 5%  - Edge case deliveries
            (.familyActivity, 2000, .easy),     // 20% - Daily activity
            (.pet, 1500, .easy),                // 15% - Pet motion
            (.pet, 300, .hard),                 // 3%  - Pet that looks suspicious
            (.falseAlarm, 1000, .medium),       // 10% - Environmental noise
            (.neighbor, 800, .medium),          // 8%  - Boundary events
            (.prowler, 400, .hard),             // 4%  - Suspicious activity
            (.burglar, 300, .hard),             // 3%  - Real threats
            (.packageTheft, 200, .hard),        // 2%  - Porch pirates
            (.maintenance, 300, .medium),       // 3%  - Service workers
            (.emergency, 100, .edgeCase),       // 1%  - Critical events
            (.delivery, 100, .edgeCase)         // 1%  - Bizarre edge cases
        ]
        
        var scenarioId = 1
        for (category, count, difficulty) in distribution {
            for _ in 0..<count {
                let scenario = generateScenario(
                    id: "BM\(String(format: "%05d", scenarioId))",
                    category: category,
                    difficulty: difficulty
                )
                scenarios.append(scenario)
                scenarioId += 1
            }
        }
        
        return scenarios.shuffled()  // Randomize order
    }
    
    // MARK: - Generate Single Scenario
    static func generateScenario(
        id: String,
        category: ScenarioCategory,
        difficulty: Difficulty
    ) -> BenchmarkScenario {
        
        switch category {
        case .delivery:
            return generateDeliveryScenario(id: id, difficulty: difficulty)
        case .burglar:
            return generateBurglarScenario(id: id, difficulty: difficulty)
        case .prowler:
            return generateProwlerScenario(id: id, difficulty: difficulty)
        case .pet:
            return generatePetScenario(id: id, difficulty: difficulty)
        case .falseAlarm:
            return generateFalseAlarmScenario(id: id, difficulty: difficulty)
        case .packageTheft:
            return generatePackageTheftScenario(id: id, difficulty: difficulty)
        case .familyActivity:
            return generateFamilyScenario(id: id, difficulty: difficulty)
        case .neighbor:
            return generateNeighborScenario(id: id, difficulty: difficulty)
        case .maintenance:
            return generateMaintenanceScenario(id: id, difficulty: difficulty)
        case .emergency:
            return generateEmergencyScenario(id: id, difficulty: difficulty)
        }
    }
    
    // MARK: - Delivery Scenarios
    static func generateDeliveryScenario(id: String, difficulty: Difficulty) -> BenchmarkScenario {
        let timeOfDay = difficulty == .easy ? Int.random(in: 10...17) : Int.random(in: 8...22)
        let homeMode = difficulty == .hard ? "away" : ["home", "away"].randomElement()!
        
        var events: [String] = []
        
        // Typical delivery: doorbell → motion → silence
        events.append("""
        {
            "event_type": "doorbell",
            "timestamp": "\(generateTimestamp(hour: timeOfDay))",
            "location": "front_door",
            "confidence": 0.95
        }
        """)
        
        // Motion within 5s
        events.append("""
        {
            "event_type": "motion",
            "timestamp": "\(generateTimestamp(hour: timeOfDay, offset: 3))",
            "location": "front_porch",
            "confidence": 0.88,
            "metadata": {
                "motion_type": "approach",
                "duration_seconds": 8
            }
        }
        """)
        
        // Silence (no more events for 60s)
        // This is represented by the absence of events
        
        if difficulty == .edgeCase {
            // Edge case: Multiple delivery attempts
            events.append("""
            {
                "event_type": "doorbell",
                "timestamp": "\(generateTimestamp(hour: timeOfDay, offset: 120))",
                "location": "front_door",
                "confidence": 0.92
            }
            """)
        }
        
        return BenchmarkScenario(
            id: id,
            category: .delivery,
            difficulty: difficulty,
            groundTruth: .safe,
            description: "Standard package delivery - should NOT alert",
            events: events,
            timeOfDay: timeOfDay,
            homeMode: homeMode,
            expectedProcessingTime: 50.0
        )
    }
    
    // MARK: - Burglar Scenarios
    static func generateBurglarScenario(id: String, difficulty: Difficulty) -> BenchmarkScenario {
        let timeOfDay = difficulty == .easy ? Int.random(in: 2...4) : Int.random(in: 22...5)
        let homeMode = "away"
        
        var events: [String] = []
        
        // Night motion
        events.append("""
        {
            "event_type": "motion",
            "timestamp": "\(generateTimestamp(hour: timeOfDay))",
            "location": "backyard",
            "confidence": 0.82,
            "metadata": {
                "motion_type": "loitering",
                "duration_seconds": 45
            }
        }
        """)
        
        // Door/window attempt
        events.append("""
        {
            "event_type": "door",
            "timestamp": "\(generateTimestamp(hour: timeOfDay, offset: 30))",
            "location": "back_door",
            "confidence": 0.91,
            "metadata": {
                "action": "opening",
                "forced": true
            }
        }
        """)
        
        // Interior motion (breach)
        events.append("""
        {
            "event_type": "motion",
            "timestamp": "\(generateTimestamp(hour: timeOfDay, offset: 45))",
            "location": "living_room",
            "confidence": 0.89,
            "metadata": {
                "motion_type": "walking",
                "duration_seconds": 120
            }
        }
        """)
        
        if difficulty == .hard {
            // Glass break
            events.append("""
            {
                "event_type": "sound",
                "timestamp": "\(generateTimestamp(hour: timeOfDay, offset: 28))",
                "location": "back_door",
                "confidence": 0.87,
                "metadata": {
                    "sound_type": "glass_break",
                    "decibels": 85
                }
            }
            """)
        }
        
        return BenchmarkScenario(
            id: id,
            category: .burglar,
            difficulty: difficulty,
            groundTruth: .critical,
            description: "Active break-in attempt - MUST alert CRITICAL",
            events: events,
            timeOfDay: timeOfDay,
            homeMode: homeMode,
            expectedProcessingTime: 50.0
        )
    }
    
    // MARK: - Prowler Scenarios
    static func generateProwlerScenario(id: String, difficulty: Difficulty) -> BenchmarkScenario {
        let timeOfDay = Int.random(in: 22...4)
        let homeMode = ["home", "away"].randomElement()!
        
        var events: [String] = []
        
        // Repeated motion without entry
        for i in 0..<3 {
            events.append("""
            {
                "event_type": "motion",
                "timestamp": "\(generateTimestamp(hour: timeOfDay, offset: i * 180))",
                "location": "\(["front_yard", "side_yard", "driveway"].randomElement()!)",
                "confidence": 0.79,
                "metadata": {
                    "motion_type": "loitering",
                    "duration_seconds": \(Int.random(in: 30...90))
                }
            }
            """)
        }
        
        return BenchmarkScenario(
            id: id,
            category: .prowler,
            difficulty: difficulty,
            groundTruth: .elevated,
            description: "Suspicious loitering - should alert ELEVATED",
            events: events,
            timeOfDay: timeOfDay,
            homeMode: homeMode,
            expectedProcessingTime: 50.0
        )
    }
    
    // MARK: - Pet Scenarios
    static func generatePetScenario(id: String, difficulty: Difficulty) -> BenchmarkScenario {
        let timeOfDay = Int.random(in: 0...23)
        let homeMode = "home"
        
        var events: [String] = []
        
        if difficulty == .hard {
            // Pet motion that LOOKS suspicious (night, repeated)
            for i in 0..<2 {
                events.append("""
                {
                    "event_type": "motion",
                    "timestamp": "\(generateTimestamp(hour: timeOfDay, offset: i * 60))",
                    "location": "living_room",
                    "confidence": 0.71,
                    "metadata": {
                        "motion_type": "pet",
                        "size": "medium",
                        "duration_seconds": 15
                    }
                }
                """)
            }
        } else {
            // Obvious pet motion
            events.append("""
            {
                "event_type": "motion",
                "timestamp": "\(generateTimestamp(hour: timeOfDay))",
                "location": "living_room",
                "confidence": 0.92,
                "metadata": {
                    "motion_type": "pet",
                    "size": "small",
                    "duration_seconds": 8
                }
            }
            """)
        }
        
        return BenchmarkScenario(
            id: id,
            category: .pet,
            difficulty: difficulty,
            groundTruth: .safe,
            description: "Pet motion - should NOT alert or dampen heavily",
            events: events,
            timeOfDay: timeOfDay,
            homeMode: homeMode,
            expectedProcessingTime: 50.0
        )
    }
    
    // MARK: - False Alarm Scenarios
    static func generateFalseAlarmScenario(id: String, difficulty: Difficulty) -> BenchmarkScenario {
        let timeOfDay = Int.random(in: 0...23)
        let homeMode = ["home", "away"].randomElement()!
        
        var events: [String] = []
        
        // Environmental noise
        events.append("""
        {
            "event_type": "\(["motion", "sound"].randomElement()!)",
            "timestamp": "\(generateTimestamp(hour: timeOfDay))",
            "location": "\(["front_yard", "backyard", "side_yard"].randomElement()!)",
            "confidence": 0.63,
            "metadata": {
                "motion_type": "environmental",
                "cause": "\(["wind", "tree_branch", "animal", "car_passing"].randomElement()!)"
            }
        }
        """)
        
        return BenchmarkScenario(
            id: id,
            category: .falseAlarm,
            difficulty: difficulty,
            groundTruth: .safe,
            description: "Environmental false alarm - should dampen or ignore",
            events: events,
            timeOfDay: timeOfDay,
            homeMode: homeMode,
            expectedProcessingTime: 50.0
        )
    }
    
    // MARK: - Package Theft Scenarios
    static func generatePackageTheftScenario(id: String, difficulty: Difficulty) -> BenchmarkScenario {
        let timeOfDay = Int.random(in: 10...20)
        let homeMode = "away"
        
        var events: [String] = []
        
        // Motion without doorbell (suspicious)
        events.append("""
        {
            "event_type": "motion",
            "timestamp": "\(generateTimestamp(hour: timeOfDay))",
            "location": "front_porch",
            "confidence": 0.84,
            "metadata": {
                "motion_type": "approach",
                "duration_seconds": 12
            }
        }
        """)
        
        // Quick departure (grabbing package)
        events.append("""
        {
            "event_type": "motion",
            "timestamp": "\(generateTimestamp(hour: timeOfDay, offset: 15))",
            "location": "front_yard",
            "confidence": 0.88,
            "metadata": {
                "motion_type": "running",
                "duration_seconds": 4
            }
        }
        """)
        
        return BenchmarkScenario(
            id: id,
            category: .packageTheft,
            difficulty: difficulty,
            groundTruth: .elevated,
            description: "Porch pirate - should alert ELEVATED",
            events: events,
            timeOfDay: timeOfDay,
            homeMode: homeMode,
            expectedProcessingTime: 50.0
        )
    }
    
    // MARK: - Family Activity Scenarios
    static func generateFamilyScenario(id: String, difficulty: Difficulty) -> BenchmarkScenario {
        let timeOfDay = Int.random(in: 6...22)
        let homeMode = "home"
        
        var events: [String] = []
        
        // Normal interior motion
        events.append("""
        {
            "event_type": "motion",
            "timestamp": "\(generateTimestamp(hour: timeOfDay))",
            "location": "\(["kitchen", "living_room", "hallway", "bedroom"].randomElement()!)",
            "confidence": 0.91,
            "metadata": {
                "motion_type": "walking",
                "duration_seconds": 20
            }
        }
        """)
        
        return BenchmarkScenario(
            id: id,
            category: .familyActivity,
            difficulty: difficulty,
            groundTruth: .safe,
            description: "Normal family activity - should NOT alert",
            events: events,
            timeOfDay: timeOfDay,
            homeMode: homeMode,
            expectedProcessingTime: 50.0
        )
    }
    
    // MARK: - Neighbor Scenarios
    static func generateNeighborScenario(id: String, difficulty: Difficulty) -> BenchmarkScenario {
        let timeOfDay = Int.random(in: 7...22)
        let homeMode = ["home", "away"].randomElement()!
        
        var events: [String] = []
        
        // Motion at property boundary
        events.append("""
        {
            "event_type": "motion",
            "timestamp": "\(generateTimestamp(hour: timeOfDay))",
            "location": "side_yard",
            "confidence": 0.68,
            "metadata": {
                "motion_type": "walking",
                "duration_seconds": 8,
                "distance": "far"
            }
        }
        """)
        
        return BenchmarkScenario(
            id: id,
            category: .neighbor,
            difficulty: difficulty,
            groundTruth: .safe,
            description: "Neighbor activity - should NOT alert or dampen",
            events: events,
            timeOfDay: timeOfDay,
            homeMode: homeMode,
            expectedProcessingTime: 50.0
        )
    }
    
    // MARK: - Maintenance Scenarios
    static func generateMaintenanceScenario(id: String, difficulty: Difficulty) -> BenchmarkScenario {
        let timeOfDay = Int.random(in: 8...17)
        let homeMode = "away"
        
        var events: [String] = []
        
        // Scheduled service (gardener, cleaner)
        events.append("""
        {
            "event_type": "motion",
            "timestamp": "\(generateTimestamp(hour: timeOfDay))",
            "location": "\(["backyard", "front_yard", "garage"].randomElement()!)",
            "confidence": 0.87,
            "metadata": {
                "motion_type": "working",
                "duration_seconds": 180
            }
        }
        """)
        
        return BenchmarkScenario(
            id: id,
            category: .maintenance,
            difficulty: difficulty,
            groundTruth: .low,
            description: "Scheduled maintenance - should alert LOW (awareness, not alarm)",
            events: events,
            timeOfDay: timeOfDay,
            homeMode: homeMode,
            expectedProcessingTime: 50.0
        )
    }
    
    // MARK: - Emergency Scenarios
    static func generateEmergencyScenario(id: String, difficulty: Difficulty) -> BenchmarkScenario {
        let timeOfDay = Int.random(in: 0...23)
        let homeMode = ["home", "away"].randomElement()!
        
        var events: [String] = []
        
        // Glass break or smoke
        events.append("""
        {
            "event_type": "\(["sound", "sensor"].randomElement()!)",
            "timestamp": "\(generateTimestamp(hour: timeOfDay))",
            "location": "\(["living_room", "kitchen", "bedroom"].randomElement()!)",
            "confidence": 0.94,
            "metadata": {
                "alert_type": "\(["glass_break", "smoke_detector", "co_detector"].randomElement()!)",
                "severity": "critical"
            }
        }
        """)
        
        return BenchmarkScenario(
            id: id,
            category: .emergency,
            difficulty: difficulty,
            groundTruth: .critical,
            description: "Emergency event - MUST alert CRITICAL immediately",
            events: events,
            timeOfDay: timeOfDay,
            homeMode: homeMode,
            expectedProcessingTime: 30.0  // Faster response needed
        )
    }
    
    // MARK: - Helper Functions
    static func generateTimestamp(hour: Int, offset: Int = 0) -> String {
        let date = Calendar.current.date(
            bySettingHour: hour % 24,
            minute: Int.random(in: 0...59),
            second: offset,
            of: Date()
        )!
        
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}

// MARK: - Export Functions
extension BenchmarkDataset {
    static func exportToJSON(scenarios: [BenchmarkScenario], filename: String = "benchmark_dataset.json") {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        if let data = try? encoder.encode(scenarios),
           let json = String(data: data, encoding: .utf8) {
            let url = URL(fileURLWithPath: "/tmp/\(filename)")
            try? json.write(to: url, atomically: true, encoding: .utf8)
            print("✅ Dataset exported to: \(url.path)")
        }
    }
}



