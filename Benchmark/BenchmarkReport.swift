// BenchmarkReport.swift - Generate Comprehensive Benchmark Reports
// Creates markdown, console, and data exports for brand pitches

import Foundation

struct BenchmarkReport {
    
    // MARK: - Generate Console Report
    static func printConsoleReport(_ results: BenchmarkResults) {
        print("\n")
        print("=" * 80)
        print("NOVININTELLIGENCE SDK v2.0 - FAT BENCHMARK REPORT")
        print("=" * 80)
        print("\n")
        
        // Overview
        printOverview(results)
        
        // Accuracy Metrics
        printAccuracyMetrics(results)
        
        // Performance Metrics
        printPerformanceMetrics(results)
        
        // Category Breakdown
        printCategoryBreakdown(results)
        
        // Difficulty Analysis
        printDifficultyAnalysis(results)
        
        // Competitive Comparison
        printCompetitiveComparison(results)
        
        // Top Failures
        printTopFailures(results)
        
        // Final Verdict
        printVerdict(results)
        
        print("=" * 80)
        print("\n")
    }
    
    // MARK: - Overview Section
    private static func printOverview(_ results: BenchmarkResults) {
        print("📊 DATASET OVERVIEW")
        print("-" * 80)
        print("Total Scenarios:        \(results.totalScenarios)")
        print("Total Processing Time:  \(String(format: "%.2f", results.totalProcessingTime))s")
        print("Scenarios/Second:       \(String(format: "%.1f", Double(results.totalScenarios) / results.totalProcessingTime))")
        print("\n")
    }
    
    // MARK: - Accuracy Metrics
    private static func printAccuracyMetrics(_ results: BenchmarkResults) {
        let accuracy = Double(results.correctPredictions) / Double(results.totalScenarios) * 100.0
        
        let fpr = Double(results.falsePositives) / Double(results.falsePositives + results.trueNegatives) * 100.0
        let fnr = Double(results.falseNegatives) / Double(results.falseNegatives + results.truePositives) * 100.0
        
        let precision = Double(results.truePositives) / Double(results.truePositives + results.falsePositives) * 100.0
        let recall = Double(results.truePositives) / Double(results.truePositives + results.falseNegatives) * 100.0
        let f1Score = 2 * (precision * recall) / (precision + recall)
        
        print("🎯 ACCURACY METRICS")
        print("-" * 80)
        print("Overall Accuracy:       \(String(format: "%.2f", accuracy))%  \(getGrade(accuracy))")
        print("")
        print("Confusion Matrix:")
        print("  True Positives:       \(results.truePositives) (threats correctly identified)")
        print("  True Negatives:       \(results.trueNegatives) (safe events correctly identified)")
        print("  False Positives:      \(results.falsePositives) (safe marked as threat) ⚠️")
        print("  False Negatives:      \(results.falseNegatives) (threats missed) 🚨")
        print("")
        print("Key Metrics:")
        print("  False Positive Rate:  \(String(format: "%.2f", fpr))%  \(getGrade(100 - fpr))")
        print("  False Negative Rate:  \(String(format: "%.2f", fnr))%  \(getGrade(100 - fnr))")
        print("  Precision:            \(String(format: "%.2f", precision))%")
        print("  Recall:               \(String(format: "%.2f", recall))%")
        print("  F1 Score:             \(String(format: "%.2f", f1Score))%")
        print("\n")
    }
    
    // MARK: - Performance Metrics
    private static func printPerformanceMetrics(_ results: BenchmarkResults) {
        guard !results.processingTimes.isEmpty else { return }
        
        let avgTime = results.processingTimes.reduce(0, +) / Double(results.processingTimes.count)
        let minTime = results.processingTimes.min() ?? 0
        let maxTime = results.processingTimes.max() ?? 0
        
        let sorted = results.processingTimes.sorted()
        let p50 = sorted[sorted.count / 2]
        let p95 = sorted[Int(Double(sorted.count) * 0.95)]
        let p99 = sorted[Int(Double(sorted.count) * 0.99)]
        
        print("⚡ PERFORMANCE METRICS")
        print("-" * 80)
        print("Processing Time (per event):")
        print("  Average:              \(String(format: "%.2f", avgTime))ms  \(avgTime < 50 ? "✅" : "⚠️")")
        print("  Minimum:              \(String(format: "%.2f", minTime))ms")
        print("  Maximum:              \(String(format: "%.2f", maxTime))ms  \(maxTime < 100 ? "✅" : "⚠️")")
        print("  50th Percentile:      \(String(format: "%.2f", p50))ms")
        print("  95th Percentile:      \(String(format: "%.2f", p95))ms")
        print("  99th Percentile:      \(String(format: "%.2f", p99))ms")
        print("")
        print("Real-Time Capable:      \(avgTime < 50 ? "YES ✅" : "NO ⚠️") (target: <50ms)")
        print("Burst Handling:         \(p99 < 100 ? "YES ✅" : "NO ⚠️") (target: <100ms p99)")
        print("\n")
    }
    
    // MARK: - Category Breakdown
    private static func printCategoryBreakdown(_ results: BenchmarkResults) {
        print("📁 SCENARIO CATEGORY BREAKDOWN")
        print("-" * 80)
        
        let sortedCategories = results.categoryResults.sorted { $0.value.total > $1.value.total }
        
        for (category, result) in sortedCategories {
            let accuracy = result.accuracy
            let grade = getGrade(accuracy)
            
            print("\(category.padding(toLength: 20, withPad: " ", startingAt: 0)): \(String(format: "%6.2f", accuracy))%  \(grade)  (\(result.correct)/\(result.total))  [\(String(format: "%.1f", result.avgProcessingTime))ms]")
            
            if result.falsePositives > 0 {
                print("  └─ False Positives:   \(result.falsePositives)")
            }
            if result.falseNegatives > 0 {
                print("  └─ False Negatives:   \(result.falseNegatives)")
            }
        }
        print("\n")
    }
    
    // MARK: - Difficulty Analysis
    private static func printDifficultyAnalysis(_ results: BenchmarkResults) {
        print("🎓 DIFFICULTY ANALYSIS")
        print("-" * 80)
        
        let difficulties: [(String, (correct: Int, total: Int))] = [
            ("Easy", results.easyAccuracy),
            ("Medium", results.mediumAccuracy),
            ("Hard", results.hardAccuracy),
            ("Edge Case", results.edgeCaseAccuracy)
        ]
        
        for (name, accuracy) in difficulties {
            let pct = accuracy.total > 0 ? Double(accuracy.correct) / Double(accuracy.total) * 100.0 : 0.0
            let grade = getGrade(pct)
            print("\(name.padding(toLength: 15, withPad: " ", startingAt: 0)): \(String(format: "%6.2f", pct))%  \(grade)  (\(accuracy.correct)/\(accuracy.total))")
        }
        print("\n")
    }
    
    // MARK: - Competitive Comparison
    private static func printCompetitiveComparison(_ results: BenchmarkResults) {
        let ourAccuracy = Double(results.correctPredictions) / Double(results.totalScenarios) * 100.0
        let ourFPR = Double(results.falsePositives) / Double(results.falsePositives + results.trueNegatives) * 100.0
        let ourFNR = Double(results.falseNegatives) / Double(results.falseNegatives + results.truePositives) * 100.0
        
        let avgTime = results.processingTimes.isEmpty ? 0 : results.processingTimes.reduce(0, +) / Double(results.processingTimes.count)
        
        print("🏆 COMPETITIVE COMPARISON")
        print("-" * 80)
        print("                        NovinIntel    Industry     Ring (est)   Nest (est)")
        print("                        ----------    --------     ----------   ----------")
        print("Accuracy:               \(String(format: "%6.2f", ourAccuracy))%       ~78%         ~75%         ~80%")
        print("False Positive Rate:    \(String(format: "%6.2f", ourFPR))%       ~35%         ~30%         ~25%")
        print("False Negative Rate:    \(String(format: "%6.2f", ourFNR))%       ~12%         ~15%         ~10%")
        print("Processing Time:        \(String(format: "%6.2f", avgTime))ms      N/A          ~80ms        ~120ms")
        print("Pet Filtering:          \(getPetAccuracy(results))%       ~45%         ~45%         ~55%")
        print("Delivery Detection:     \(getDeliveryAccuracy(results))%       ~65%         ~65%         ~70%")
        print("")
        print("VERDICT: \(ourAccuracy > 85 && ourFPR < 15 ? "✅ MARKET-LEADING" : "⚠️ NEEDS IMPROVEMENT")")
        print("\n")
    }
    
    // MARK: - Top Failures
    private static func printTopFailures(_ results: BenchmarkResults) {
        guard !results.failures.isEmpty else {
            print("🎉 NO FAILURES - PERFECT PERFORMANCE!\n")
            return
        }
        
        print("⚠️  TOP FAILURES (showing first 10)")
        print("-" * 80)
        
        let topFailures = Array(results.failures.prefix(10))
        
        for (index, failure) in topFailures.enumerated() {
            print("\(index + 1). [\(failure.scenarioId)] \(failure.category) (\(failure.difficulty))")
            print("   Expected: \(failure.expected.rawValue)  |  Predicted: \(failure.predicted.rawValue)")
            print("   Reason: \(failure.description)")
            print("   Time: \(String(format: "%.2f", failure.processingTime))ms")
            print("")
        }
        print("\n")
    }
    
    // MARK: - Verdict
    private static func printVerdict(_ results: BenchmarkResults) {
        let accuracy = Double(results.correctPredictions) / Double(results.totalScenarios) * 100.0
        let fpr = Double(results.falsePositives) / Double(results.falsePositives + results.trueNegatives) * 100.0
        let fnr = Double(results.falseNegatives) / Double(results.falseNegatives + results.truePositives) * 100.0
        
        let avgTime = results.processingTimes.isEmpty ? 0 : results.processingTimes.reduce(0, +) / Double(results.processingTimes.count)
        
        print("🎖️  FINAL VERDICT")
        print("-" * 80)
        
        var score = 0
        var maxScore = 5
        
        // Criterion 1: Accuracy > 90%
        if accuracy > 90 {
            print("✅ Accuracy > 90%: PASS")
            score += 1
        } else {
            print("❌ Accuracy > 90%: FAIL (\(String(format: "%.2f", accuracy))%)")
        }
        
        // Criterion 2: FPR < 10%
        if fpr < 10 {
            print("✅ False Positive Rate < 10%: PASS")
            score += 1
        } else {
            print("❌ False Positive Rate < 10%: FAIL (\(String(format: "%.2f", fpr))%)")
        }
        
        // Criterion 3: FNR < 5%
        if fnr < 5 {
            print("✅ False Negative Rate < 5%: PASS")
            score += 1
        } else {
            print("❌ False Negative Rate < 5%: FAIL (\(String(format: "%.2f", fnr))%)")
        }
        
        // Criterion 4: Avg time < 50ms
        if avgTime < 50 {
            print("✅ Processing Time < 50ms: PASS")
            score += 1
        } else {
            print("❌ Processing Time < 50ms: FAIL (\(String(format: "%.2f", avgTime))ms)")
        }
        
        // Criterion 5: Pet accuracy > 85%
        let petAccuracy = getPetAccuracyValue(results)
        if petAccuracy > 85 {
            print("✅ Pet Filtering > 85%: PASS")
            score += 1
        } else {
            print("❌ Pet Filtering > 85%: FAIL (\(String(format: "%.2f", petAccuracy))%)")
        }
        
        print("")
        print("SCORE: \(score)/\(maxScore)")
        print("")
        
        if score == maxScore {
            print("🏆 PRODUCTION-READY - READY TO PITCH BRANDS!")
            print("   SDK is fool-proof and market-leading.")
        } else if score >= 3 {
            print("⚠️  MOSTLY READY - Minor improvements needed")
            print("   SDK is functional but has gaps to address.")
        } else {
            print("🚨 NOT READY - Significant issues detected")
            print("   SDK needs major improvements before pitching.")
        }
        
        print("\n")
    }
    
    // MARK: - Helper Functions
    private static func getGrade(_ percentage: Double) -> String {
        switch percentage {
        case 95...100: return "🟢 A+"
        case 90..<95: return "🟢 A"
        case 85..<90: return "🟡 B+"
        case 80..<85: return "🟡 B"
        case 75..<80: return "🟠 C+"
        case 70..<75: return "🟠 C"
        default: return "🔴 D"
        }
    }
    
    private static func getPetAccuracy(_ results: BenchmarkResults) -> String {
        if let petResult = results.categoryResults["pet"] {
            return String(format: "%6.2f", petResult.accuracy)
        }
        return "   N/A"
    }
    
    private static func getPetAccuracyValue(_ results: BenchmarkResults) -> Double {
        if let petResult = results.categoryResults["pet"] {
            return petResult.accuracy
        }
        return 0.0
    }
    
    private static func getDeliveryAccuracy(_ results: BenchmarkResults) -> String {
        if let deliveryResult = results.categoryResults["delivery"] {
            return String(format: "%6.2f", deliveryResult.accuracy)
        }
        return "   N/A"
    }
    
    // MARK: - Generate Markdown Report
    static func generateMarkdownReport(_ results: BenchmarkResults) -> String {
        let accuracy = Double(results.correctPredictions) / Double(results.totalScenarios) * 100.0
        let fpr = Double(results.falsePositives) / Double(results.falsePositives + results.trueNegatives) * 100.0
        let fnr = Double(results.falseNegatives) / Double(results.falseNegatives + results.truePositives) * 100.0
        let avgTime = results.processingTimes.isEmpty ? 0 : results.processingTimes.reduce(0, +) / Double(results.processingTimes.count)
        
        var markdown = """
        # NovinIntelligence SDK v2.0 - Benchmark Report
        
        **Date**: \(Date())
        **Dataset Size**: \(results.totalScenarios) scenarios
        **Total Processing Time**: \(String(format: "%.2f", results.totalProcessingTime))s
        
        ---
        
        ## Executive Summary
        
        NovinIntelligence SDK was benchmarked against \(results.totalScenarios) realistic smart home security scenarios covering deliveries, burglaries, prowlers, pets, and false alarms.
        
        ### Key Results
        - **Overall Accuracy**: \(String(format: "%.2f", accuracy))%
        - **False Positive Rate**: \(String(format: "%.2f", fpr))% (vs. ~35% industry baseline)
        - **False Negative Rate**: \(String(format: "%.2f", fnr))% (vs. ~12% industry baseline)
        - **Average Processing Time**: \(String(format: "%.2f", avgTime))ms (target: <50ms)
        
        ---
        
        ## Performance Breakdown
        
        ### Accuracy Metrics
        
        | Metric | Value | Target | Status |
        |--------|-------|--------|--------|
        | Overall Accuracy | \(String(format: "%.2f", accuracy))% | >90% | \(accuracy > 90 ? "✅ PASS" : "❌ FAIL") |
        | False Positive Rate | \(String(format: "%.2f", fpr))% | <10% | \(fpr < 10 ? "✅ PASS" : "❌ FAIL") |
        | False Negative Rate | \(String(format: "%.2f", fnr))% | <5% | \(fnr < 5 ? "✅ PASS" : "❌ FAIL") |
        | Processing Time | \(String(format: "%.2f", avgTime))ms | <50ms | \(avgTime < 50 ? "✅ PASS" : "❌ FAIL") |
        
        ### Category Performance
        
        | Category | Accuracy | False Positives | False Negatives |
        |----------|----------|-----------------|-----------------|
        """
        
        let sortedCategories = results.categoryResults.sorted { $0.key < $1.key }
        for (category, result) in sortedCategories {
            markdown += "| \(category) | \(String(format: "%.2f", result.accuracy))% | \(result.falsePositives) | \(result.falseNegatives) |\n"
        }
        
        markdown += """
        
        ---
        
        ## Competitive Analysis
        
        | Metric | NovinIntelligence | Industry Baseline | Ring (est) | Nest (est) |
        |--------|-------------------|-------------------|------------|------------|
        | Accuracy | \(String(format: "%.2f", accuracy))% | ~78% | ~75% | ~80% |
        | False Positive Rate | \(String(format: "%.2f", fpr))% | ~35% | ~30% | ~25% |
        | False Negative Rate | \(String(format: "%.2f", fnr))% | ~12% | ~15% | ~10% |
        | Processing Time | \(String(format: "%.2f", avgTime))ms | N/A | ~80ms | ~120ms |
        
        **Verdict**: \(accuracy > 85 && fpr < 15 ? "✅ Market-leading performance" : "⚠️ Competitive but needs improvement")
        
        ---
        
        ## Conclusion
        
        NovinIntelligence SDK demonstrates \(accuracy > 90 ? "production-ready" : "functional") performance with \(fpr < 10 ? "industry-leading" : "competitive") false positive rates. The SDK is \(avgTime < 50 ? "real-time capable" : "approaching real-time performance") and ready for \(accuracy > 90 && fpr < 10 ? "immediate brand integration" : "pilot testing with brands").
        
        """
        
        return markdown
    }
    
    // MARK: - Export to File
    static func exportMarkdownReport(_ results: BenchmarkResults, filename: String = "benchmark_report.md") {
        let markdown = generateMarkdownReport(results)
        let url = URL(fileURLWithPath: "/tmp/\(filename)")
        try? markdown.write(to: url, atomically: true, encoding: .utf8)
        print("📄 Markdown report exported to: \(url.path)")
    }
    
    static func exportJSONResults(_ results: BenchmarkResults, filename: String = "benchmark_results.json") {
        // Convert results to JSON-compatible dictionary
        var jsonDict: [String: Any] = [:]
        jsonDict["total_scenarios"] = results.totalScenarios
        jsonDict["correct_predictions"] = results.correctPredictions
        jsonDict["incorrect_predictions"] = results.incorrectPredictions
        jsonDict["accuracy"] = Double(results.correctPredictions) / Double(results.totalScenarios) * 100.0
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let url = URL(fileURLWithPath: "/tmp/\(filename)")
            try? jsonString.write(to: url, atomically: true, encoding: .utf8)
            print("📊 JSON results exported to: \(url.path)")
        }
    }
}

// MARK: - String Extension
private extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}



