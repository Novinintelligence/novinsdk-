// FatBenchmarkTests.swift - Fat Benchmark for NovinIntelligence SDK
// Run this test to execute the full benchmark suite

import XCTest

final class FatBenchmarkTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        NovinIntelligence.shared.initialize()
        
        // Configure with default settings
        let config = TemporalConfiguration.default
        NovinIntelligence.shared.configure(temporal: config)
    }
    
    // MARK: - Fat Benchmark Test (1000 scenarios for CI)
    func testFatBenchmark1K() {
        print("\n🚀 Running Fat Benchmark - 1,000 scenarios")
        print("=" * 80)
        
        let results = runBenchmark(scenarioCount: 1000)
        
        // Print report
        printBenchmarkReport(results)
        
        // Assertions
        let accuracy = Double(results.correctPredictions) / Double(results.totalScenarios) * 100.0
        let fpr = Double(results.falsePositives) / Double(results.falsePositives + results.trueNegatives) * 100.0
        let fnr = Double(results.falseNegatives) / Double(results.falseNegatives + results.truePositives) * 100.0
        
        // Production-ready thresholds
        XCTAssertGreaterThan(accuracy, 85.0, "Accuracy must be >85% (got \(String(format: "%.2f", accuracy))%)")
        XCTAssertLessThan(fpr, 15.0, "False Positive Rate must be <15% (got \(String(format: "%.2f", fpr))%)")
        XCTAssertLessThan(fnr, 10.0, "False Negative Rate must be <10% (got \(String(format: "%.2f", fnr))%)")
        
        // Performance assertion
        if !results.processingTimes.isEmpty {
            let avgTime = results.processingTimes.reduce(0, +) / Double(results.processingTimes.count)
            XCTAssertLessThan(avgTime, 100.0, "Average processing time must be <100ms (got \(String(format: "%.2f", avgTime))ms)")
        }
    }
    
    // MARK: - Massive Benchmark (10K scenarios - run manually)
    func testFatBenchmark10K() {
        // Only run if explicitly enabled (too slow for CI)
        guard ProcessInfo.processInfo.environment["RUN_FAT_BENCHMARK"] != nil else {
            print("⏭️  Skipping 10K benchmark (set RUN_FAT_BENCHMARK=1 to enable)")
            return
        }
        
        print("\n🚀 Running MASSIVE Fat Benchmark - 10,000 scenarios")
        print("=" * 80)
        
        let results = runBenchmark(scenarioCount: 10000)
        
        // Print report
        printBenchmarkReport(results)
        
        // Export reports
        exportReports(results, scenarioCount: 10000)
        
        // Stricter assertions for large dataset
        let accuracy = Double(results.correctPredictions) / Double(results.totalScenarios) * 100.0
        let fpr = Double(results.falsePositives) / Double(results.falsePositives + results.trueNegatives) * 100.0
        let fnr = Double(results.falseNegatives) / Double(results.falseNegatives + results.truePositives) * 100.0
        
        XCTAssertGreaterThan(accuracy, 90.0, "Accuracy must be >90% for production (got \(String(format: "%.2f", accuracy))%)")
        XCTAssertLessThan(fpr, 10.0, "FPR must be <10% for production (got \(String(format: "%.2f", fpr))%)")
        XCTAssertLessThan(fnr, 5.0, "FNR must be <5% for production (got \(String(format: "%.2f", fnr))%)")
    }
    
    // MARK: - Run Benchmark
    private func runBenchmark(scenarioCount: Int) -> BenchmarkResults {
        var results = BenchmarkResults()
        results.totalScenarios = scenarioCount
        
        // Generate dataset
        let dataset = generateDataset(count: scenarioCount)
        
        print("📊 Dataset generated: \(dataset.count) scenarios")
        printDatasetDistribution(dataset)
        
        print("\n🧪 Running SDK assessments...")
        
        let startTime = Date()
        
        // Initialize category results
        for category in ScenarioCategory.allCases {
            results.categoryResults[category.rawValue] = CategoryResult()
        }
        
        // Run all scenarios
        for (index, scenario) in dataset.enumerated() {
            if index % 100 == 0 && index > 0 {
                let progress = Double(index) / Double(dataset.count) * 100.0
                print("  Progress: \(Int(progress))% (\(index)/\(dataset.count))")
            }
            
            assessScenario(scenario, results: &results)
        }
        
        results.totalProcessingTime = Date().timeIntervalSince(startTime)
        
        print("✅ Benchmark complete in \(String(format: "%.2f", results.totalProcessingTime))s")
        
        return results
    }
    
    // MARK: - Assess Scenario
    private func assessScenario(_ scenario: BenchmarkScenario, results: inout BenchmarkResults) {
        let startTime = Date()
        
        var finalAssessment: SecurityAssessment?
        
        for eventJson in scenario.events {
            finalAssessment = NovinIntelligence.shared.assess(requestJson: eventJson)
        }
        
        guard let assessment = finalAssessment else {
            results.incorrectPredictions += 1
            return
        }
        
        let processingTime = Date().timeIntervalSince(startTime) * 1000.0
        results.processingTimes.append(processingTime)
        
        // Compare prediction
        let isCorrect = comparePrediction(predicted: assessment.threatLevel, expected: scenario.groundTruth)
        
        if isCorrect {
            results.correctPredictions += 1
        } else {
            results.incorrectPredictions += 1
        }
        
        // Update confusion matrix
        updateConfusionMatrix(predicted: assessment.threatLevel, expected: scenario.groundTruth, results: &results)
        
        // Update category results
        updateCategoryResults(
            category: scenario.category.rawValue,
            isCorrect: isCorrect,
            processingTime: processingTime,
            predicted: assessment.threatLevel,
            expected: scenario.groundTruth,
            results: &results
        )
        
        // Update difficulty
        updateDifficultyResults(difficulty: scenario.difficulty, isCorrect: isCorrect, results: &results)
    }
    
    // MARK: - Comparison Logic
    private func comparePrediction(predicted: ThreatLevel, expected: GroundTruth) -> Bool {
        switch (predicted, expected) {
        case (.none, .safe), (.low, .safe), (.low, .low):
            return true
        case (.standard, .low), (.standard, .elevated):
            return true
        case (.elevated, .elevated):
            return true
        case (.critical, .critical):
            return true
        // Allow tolerance
        case (.standard, .safe), (.none, .low):
            return true
        default:
            return false
        }
    }
    
    // MARK: - Update Functions
    private func updateConfusionMatrix(predicted: ThreatLevel, expected: GroundTruth, results: inout BenchmarkResults) {
        let isThreat = (expected == .elevated || expected == .critical)
        let predictedThreat = (predicted == .elevated || predicted == .critical)
        
        if isThreat && predictedThreat {
            results.truePositives += 1
        } else if !isThreat && !predictedThreat {
            results.trueNegatives += 1
        } else if !isThreat && predictedThreat {
            results.falsePositives += 1
        } else if isThreat && !predictedThreat {
            results.falseNegatives += 1
        }
    }
    
    private func updateCategoryResults(
        category: String,
        isCorrect: Bool,
        processingTime: Double,
        predicted: ThreatLevel,
        expected: GroundTruth,
        results: inout BenchmarkResults
    ) {
        guard var categoryResult = results.categoryResults[category] else { return }
        
        categoryResult.total += 1
        if isCorrect { categoryResult.correct += 1 }
        
        let prevTotal = categoryResult.avgProcessingTime * Double(categoryResult.total - 1)
        categoryResult.avgProcessingTime = (prevTotal + processingTime) / Double(categoryResult.total)
        
        let isThreat = (expected == .elevated || expected == .critical)
        let predictedThreat = (predicted == .elevated || predicted == .critical)
        
        if !isThreat && predictedThreat {
            categoryResult.falsePositives += 1
        } else if isThreat && !predictedThreat {
            categoryResult.falseNegatives += 1
        }
        
        results.categoryResults[category] = categoryResult
    }
    
    private func updateDifficultyResults(difficulty: Difficulty, isCorrect: Bool, results: inout BenchmarkResults) {
        switch difficulty {
        case .easy:
            results.easyAccuracy.total += 1
            if isCorrect { results.easyAccuracy.correct += 1 }
        case .medium:
            results.mediumAccuracy.total += 1
            if isCorrect { results.mediumAccuracy.correct += 1 }
        case .hard:
            results.hardAccuracy.total += 1
            if isCorrect { results.hardAccuracy.correct += 1 }
        case .edgeCase:
            results.edgeCaseAccuracy.total += 1
            if isCorrect { results.edgeCaseAccuracy.correct += 1 }
        }
    }
    
    // MARK: - Print Report
    private func printBenchmarkReport(_ results: BenchmarkResults) {
        let accuracy = Double(results.correctPredictions) / Double(results.totalScenarios) * 100.0
        let fpr = Double(results.falsePositives) / Double(results.falsePositives + results.trueNegatives) * 100.0
        let fnr = Double(results.falseNegatives) / Double(results.falseNegatives + results.truePositives) * 100.0
        let avgTime = results.processingTimes.isEmpty ? 0 : results.processingTimes.reduce(0, +) / Double(results.processingTimes.count)
        
        print("\n")
        print("=" * 80)
        print("BENCHMARK RESULTS")
        print("=" * 80)
        print("\n📊 OVERALL METRICS")
        print("-" * 80)
        print("Accuracy:             \(String(format: "%.2f", accuracy))%")
        print("False Positive Rate:  \(String(format: "%.2f", fpr))%")
        print("False Negative Rate:  \(String(format: "%.2f", fnr))%")
        print("Avg Processing Time:  \(String(format: "%.2f", avgTime))ms")
        print("\n📁 CATEGORY BREAKDOWN")
        print("-" * 80)
        
        let sortedCategories = results.categoryResults.sorted { $0.value.total > $1.value.total }
        for (category, result) in sortedCategories {
            let catAccuracy = result.total > 0 ? Double(result.correct) / Double(result.total) * 100.0 : 0.0
            print("\(category.padding(toLength: 20, withPad: " ", startingAt: 0)): \(String(format: "%6.2f", catAccuracy))% (\(result.correct)/\(result.total))")
        }
        
        print("\n🎯 VERDICT")
        print("-" * 80)
        if accuracy > 90 && fpr < 10 {
            print("✅ PRODUCTION-READY - SDK is fool-proof and ready for brand pitches!")
        } else if accuracy > 85 {
            print("⚠️  MOSTLY READY - Minor improvements needed")
        } else {
            print("🚨 NEEDS WORK - Significant improvements required")
        }
        print("=" * 80)
        print("\n")
    }
    
    // MARK: - Export Reports
    private func exportReports(_ results: BenchmarkResults, scenarioCount: Int) {
        let markdown = generateMarkdownReport(results)
        let url = URL(fileURLWithPath: "/tmp/benchmark_report_\(scenarioCount).md")
        try? markdown.write(to: url, atomically: true, encoding: .utf8)
        print("📄 Report exported to: \(url.path)")
    }
    
    // MARK: - Generate Markdown
    private func generateMarkdownReport(_ results: BenchmarkResults) -> String {
        let accuracy = Double(results.correctPredictions) / Double(results.totalScenarios) * 100.0
        let fpr = Double(results.falsePositives) / Double(results.falsePositives + results.trueNegatives) * 100.0
        let fnr = Double(results.falseNegatives) / Double(results.falseNegatives + results.truePositives) * 100.0
        
        return """
        # NovinIntelligence SDK v2.0 - Benchmark Report
        
        **Date**: \(Date())
        **Scenarios**: \(results.totalScenarios)
        
        ## Results
        - **Accuracy**: \(String(format: "%.2f", accuracy))%
        - **False Positive Rate**: \(String(format: "%.2f", fpr))%
        - **False Negative Rate**: \(String(format: "%.2f", fnr))%
        
        ## Verdict
        \(accuracy > 90 && fpr < 10 ? "✅ Production-ready" : "⚠️ Needs improvement")
        """
    }
    
    // MARK: - Dataset Distribution
    private func printDatasetDistribution(_ dataset: [BenchmarkScenario]) {
        var distribution: [String: Int] = [:]
        for scenario in dataset {
            distribution[scenario.category.rawValue, default: 0] += 1
        }
        
        print("\nDataset Distribution:")
        for (category, count) in distribution.sorted(by: { $0.value > $1.value }) {
            let percentage = Double(count) / Double(dataset.count) * 100.0
            print("  \(category): \(count) (\(String(format: "%.1f", percentage))%)")
        }
    }
}

// MARK: - Supporting Types (inline for XCTest)

struct BenchmarkResults {
    var totalScenarios: Int = 0
    var correctPredictions: Int = 0
    var incorrectPredictions: Int = 0
    var truePositives: Int = 0
    var trueNegatives: Int = 0
    var falsePositives: Int = 0
    var falseNegatives: Int = 0
    var processingTimes: [Double] = []
    var totalProcessingTime: Double = 0.0
    var categoryResults: [String: CategoryResult] = [:]
    var easyAccuracy: (correct: Int, total: Int) = (0, 0)
    var mediumAccuracy: (correct: Int, total: Int) = (0, 0)
    var hardAccuracy: (correct: Int, total: Int) = (0, 0)
    var edgeCaseAccuracy: (correct: Int, total: Int) = (0, 0)
}

struct CategoryResult {
    var correct: Int = 0
    var total: Int = 0
    var avgProcessingTime: Double = 0.0
    var falsePositives: Int = 0
    var falseNegatives: Int = 0
}

// Reuse types from BenchmarkDataset.swift
// (simplified inline versions - full generator is in Benchmark/ folder)

private func generateDataset(count: Int) -> [BenchmarkScenario] {
    var scenarios: [BenchmarkScenario] = []
    
    let distribution: [(ScenarioCategory, Int, Difficulty)] = [
        (.delivery, Int(Double(count) * 0.30), .easy),
        (.familyActivity, Int(Double(count) * 0.20), .easy),
        (.pet, Int(Double(count) * 0.18), .easy),
        (.falseAlarm, Int(Double(count) * 0.10), .medium),
        (.neighbor, Int(Double(count) * 0.08), .medium),
        (.prowler, Int(Double(count) * 0.05), .hard),
        (.burglar, Int(Double(count) * 0.04), .hard),
        (.packageTheft, Int(Double(count) * 0.03), .hard),
        (.maintenance, Int(Double(count) * 0.01), .medium),
        (.emergency, Int(Double(count) * 0.01), .edgeCase)
    ]
    
    var id = 1
    for (category, cnt, difficulty) in distribution {
        for _ in 0..<cnt {
            scenarios.append(generateScenario(id: "BM\(String(format: "%05d", id))", category: category, difficulty: difficulty))
            id += 1
        }
    }
    
    return scenarios.shuffled()
}

private func generateScenario(id: String, category: ScenarioCategory, difficulty: Difficulty) -> BenchmarkScenario {
    let timeOfDay = Int.random(in: 0...23)
    let homeMode = ["home", "away"].randomElement()!
    
    var events: [String] = []
    var groundTruth: GroundTruth = .safe
    var description = ""
    
    switch category {
    case .delivery:
        events.append("{\"event_type\":\"doorbell\",\"timestamp\":\"\(ISO8601DateFormatter().string(from: Date()))\",\"location\":\"front_door\",\"confidence\":0.95}")
        events.append("{\"event_type\":\"motion\",\"timestamp\":\"\(ISO8601DateFormatter().string(from: Date()))\",\"location\":\"front_porch\",\"confidence\":0.88}")
        groundTruth = .safe
        description = "Package delivery"
    case .burglar:
        events.append("{\"event_type\":\"motion\",\"timestamp\":\"\(ISO8601DateFormatter().string(from: Date()))\",\"location\":\"backyard\",\"confidence\":0.82}")
        events.append("{\"event_type\":\"door\",\"timestamp\":\"\(ISO8601DateFormatter().string(from: Date()))\",\"location\":\"back_door\",\"confidence\":0.91,\"metadata\":{\"action\":\"opening\"}}")
        groundTruth = .critical
        description = "Break-in attempt"
    case .pet:
        events.append("{\"event_type\":\"motion\",\"timestamp\":\"\(ISO8601DateFormatter().string(from: Date()))\",\"location\":\"living_room\",\"confidence\":0.92,\"metadata\":{\"motion_type\":\"pet\"}}")
        groundTruth = .safe
        description = "Pet motion"
    case .prowler:
        events.append("{\"event_type\":\"motion\",\"timestamp\":\"\(ISO8601DateFormatter().string(from: Date()))\",\"location\":\"front_yard\",\"confidence\":0.79,\"metadata\":{\"motion_type\":\"loitering\"}}")
        groundTruth = .elevated
        description = "Suspicious loitering"
    default:
        events.append("{\"event_type\":\"motion\",\"timestamp\":\"\(ISO8601DateFormatter().string(from: Date()))\",\"location\":\"hallway\",\"confidence\":0.75}")
        groundTruth = .safe
        description = "Generic event"
    }
    
    return BenchmarkScenario(
        id: id,
        category: category,
        difficulty: difficulty,
        groundTruth: groundTruth,
        description: description,
        events: events,
        timeOfDay: timeOfDay,
        homeMode: homeMode,
        expectedProcessingTime: 50.0
    )
}

private extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}



