// BenchmarkRunner.swift - Fat Benchmark Execution Engine
// Tests NovinIntelligence SDK against 10,000+ scenarios

import Foundation

// MARK: - Benchmark Results Tracking
struct BenchmarkResults {
    // Overall metrics
    var totalScenarios: Int = 0
    var correctPredictions: Int = 0
    var incorrectPredictions: Int = 0
    
    // Confusion matrix components
    var truePositives: Int = 0      // Correctly identified threats
    var trueNegatives: Int = 0      // Correctly identified safe events
    var falsePositives: Int = 0     // Safe events marked as threats
    var falseNegatives: Int = 0     // Threats marked as safe
    
    // Performance tracking
    var processingTimes: [Double] = []
    var totalProcessingTime: Double = 0.0
    
    // Category-specific accuracy
    var categoryResults: [String: CategoryResult] = [:]
    
    // Difficulty breakdown
    var easyAccuracy: (correct: Int, total: Int) = (0, 0)
    var mediumAccuracy: (correct: Int, total: Int) = (0, 0)
    var hardAccuracy: (correct: Int, total: Int) = (0, 0)
    var edgeCaseAccuracy: (correct: Int, total: Int) = (0, 0)
    
    // Detailed failure tracking
    var failures: [BenchmarkFailure] = []
}

struct CategoryResult {
    var correct: Int = 0
    var total: Int = 0
    var avgProcessingTime: Double = 0.0
    var falsePositives: Int = 0
    var falseNegatives: Int = 0
    
    var accuracy: Double {
        total > 0 ? Double(correct) / Double(total) * 100.0 : 0.0
    }
}

struct BenchmarkFailure {
    let scenarioId: String
    let category: String
    let difficulty: String
    let expected: GroundTruth
    let predicted: ThreatLevel
    let description: String
    let processingTime: Double
}

// MARK: - Benchmark Runner
class BenchmarkRunner {
    
    static let shared = BenchmarkRunner()
    private var results = BenchmarkResults()
    
    // MARK: - Run Full Benchmark
    func runFullBenchmark(scenarioCount: Int = 10000, verbose: Bool = true) -> BenchmarkResults {
        print("🚀 Starting Fat Benchmark - \(scenarioCount) scenarios")
        print("=" * 80)
        
        // Generate dataset
        if verbose {
            print("📊 Generating benchmark dataset...")
        }
        let dataset = BenchmarkDataset.generate(count: scenarioCount)
        
        if verbose {
            print("✅ Dataset generated: \(dataset.count) scenarios")
            printDatasetDistribution(dataset)
        }
        
        // Initialize results
        results = BenchmarkResults()
        results.totalScenarios = dataset.count
        
        // Initialize category trackers
        for category in ScenarioCategory.allCases {
            results.categoryResults[category.rawValue] = CategoryResult()
        }
        
        // Run benchmark
        if verbose {
            print("\n🧪 Running SDK assessment on all scenarios...")
        }
        
        let startTime = Date()
        
        for (index, scenario) in dataset.enumerated() {
            // Progress indicator
            if verbose && index % 1000 == 0 {
                let progress = Double(index) / Double(dataset.count) * 100.0
                print("Progress: \(Int(progress))% (\(index)/\(dataset.count))")
            }
            
            // Run scenario
            assessScenario(scenario)
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        results.totalProcessingTime = totalTime
        
        if verbose {
            print("\n✅ Benchmark complete in \(String(format: "%.2f", totalTime))s")
            print("=" * 80)
        }
        
        return results
    }
    
    // MARK: - Assess Single Scenario
    private func assessScenario(_ scenario: BenchmarkScenario) {
        let startTime = Date()
        
        // Process all events in scenario
        var finalAssessment: SecurityAssessment?
        
        for eventJson in scenario.events {
            // Call SDK
            let assessment = NovinIntelligence.shared.assess(requestJson: eventJson)
            finalAssessment = assessment
        }
        
        guard let assessment = finalAssessment else {
            // SDK failed to process
            recordFailure(scenario: scenario, predicted: .low, processingTime: 0, reason: "SDK processing failed")
            return
        }
        
        let processingTime = Date().timeIntervalSince(startTime) * 1000.0  // Convert to ms
        results.processingTimes.append(processingTime)
        
        // Map threat level to ground truth for comparison
        let isCorrect = comparePrediction(
            predicted: assessment.threatLevel,
            expected: scenario.groundTruth
        )
        
        // Update results
        if isCorrect {
            results.correctPredictions += 1
        } else {
            results.incorrectPredictions += 1
            recordFailure(
                scenario: scenario,
                predicted: assessment.threatLevel,
                processingTime: processingTime,
                reason: "Misclassification"
            )
        }
        
        // Update confusion matrix
        updateConfusionMatrix(
            predicted: assessment.threatLevel,
            expected: scenario.groundTruth
        )
        
        // Update category results
        updateCategoryResults(
            category: scenario.category.rawValue,
            isCorrect: isCorrect,
            processingTime: processingTime,
            predicted: assessment.threatLevel,
            expected: scenario.groundTruth
        )
        
        // Update difficulty breakdown
        updateDifficultyResults(
            difficulty: scenario.difficulty,
            isCorrect: isCorrect
        )
        
        // Check processing time
        if processingTime > scenario.expectedProcessingTime {
            // Performance issue
            recordFailure(
                scenario: scenario,
                predicted: assessment.threatLevel,
                processingTime: processingTime,
                reason: "Processing time exceeded: \(processingTime)ms > \(scenario.expectedProcessingTime)ms"
            )
        }
    }
    
    // MARK: - Comparison Logic
    private func comparePrediction(predicted: ThreatLevel, expected: GroundTruth) -> Bool {
        // Map threat levels to ground truth categories
        switch (predicted, expected) {
        case (.none, .safe), (.low, .safe), (.low, .low):
            return true
        case (.standard, .low), (.standard, .elevated):
            return true
        case (.elevated, .elevated), (.elevated, .low):
            return true
        case (.critical, .critical):
            return true
        // Allow some tolerance for borderline cases
        case (.low, .low), (.standard, .safe):
            return true  // Slight over-caution is acceptable
        case (.none, .low):
            return true  // Slight under-caution for very low threats
        default:
            return false
        }
    }
    
    // MARK: - Update Confusion Matrix
    private func updateConfusionMatrix(predicted: ThreatLevel, expected: GroundTruth) {
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
    
    // MARK: - Update Category Results
    private func updateCategoryResults(
        category: String,
        isCorrect: Bool,
        processingTime: Double,
        predicted: ThreatLevel,
        expected: GroundTruth
    ) {
        guard var categoryResult = results.categoryResults[category] else { return }
        
        categoryResult.total += 1
        if isCorrect {
            categoryResult.correct += 1
        }
        
        // Update avg processing time
        let prevTotal = categoryResult.avgProcessingTime * Double(categoryResult.total - 1)
        categoryResult.avgProcessingTime = (prevTotal + processingTime) / Double(categoryResult.total)
        
        // Track FP/FN per category
        let isThreat = (expected == .elevated || expected == .critical)
        let predictedThreat = (predicted == .elevated || predicted == .critical)
        
        if !isThreat && predictedThreat {
            categoryResult.falsePositives += 1
        } else if isThreat && !predictedThreat {
            categoryResult.falseNegatives += 1
        }
        
        results.categoryResults[category] = categoryResult
    }
    
    // MARK: - Update Difficulty Results
    private func updateDifficultyResults(difficulty: Difficulty, isCorrect: Bool) {
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
    
    // MARK: - Record Failure
    private func recordFailure(
        scenario: BenchmarkScenario,
        predicted: ThreatLevel,
        processingTime: Double,
        reason: String
    ) {
        let failure = BenchmarkFailure(
            scenarioId: scenario.id,
            category: scenario.category.rawValue,
            difficulty: scenario.difficulty.rawValue,
            expected: scenario.groundTruth,
            predicted: predicted,
            description: reason,
            processingTime: processingTime
        )
        results.failures.append(failure)
    }
    
    // MARK: - Print Dataset Distribution
    private func printDatasetDistribution(_ dataset: [BenchmarkScenario]) {
        var distribution: [String: Int] = [:]
        for scenario in dataset {
            distribution[scenario.category.rawValue, default: 0] += 1
        }
        
        print("\nDataset Distribution:")
        for (category, count) in distribution.sorted(by: { $0.value > $1.value }) {
            let percentage = Double(count) / Double(dataset.count) * 100.0
            print("  \(category.padding(toLength: 20, withPad: " ", startingAt: 0)): \(count) (\(String(format: "%.1f", percentage))%)")
        }
    }
    
    // MARK: - Get Results
    func getResults() -> BenchmarkResults {
        return results
    }
}

// MARK: - String Extension
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}



