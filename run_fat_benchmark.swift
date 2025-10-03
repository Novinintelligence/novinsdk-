#!/usr/bin/env swift

// run_fat_benchmark.swift - Execute Fat Benchmark on NovinIntelligence SDK
// Usage: swift run_fat_benchmark.swift [scenario_count]
//
// This script stress-tests the SDK with 10,000+ realistic scenarios
// and generates a comprehensive report for brand pitches.

import Foundation

print("""

╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║              NOVININTELLIGENCE SDK v2.0 - FAT BENCHMARK                      ║
║              Fool-Proof AI Validation for Brand Pitches                      ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

""")

// Parse arguments
let scenarioCount = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 10000 : 10000

print("Configuration:")
print("  • Scenario Count: \(scenarioCount)")
print("  • SDK Version: 2.0.0-enterprise")
print("  • Test Date: \(Date())")
print("")

// Initialize SDK
print("🔧 Initializing NovinIntelligence SDK...")
NovinIntelligence.shared.initialize()
print("✅ SDK initialized\n")

// Configure SDK (use default settings for benchmark)
let defaultConfig = TemporalConfiguration.default
NovinIntelligence.shared.configure(temporal: defaultConfig)
print("✅ SDK configured with default settings\n")

// Run benchmark
print("🚀 Starting benchmark run...")
print("   This will take approximately \(scenarioCount / 100) seconds\n")

let runner = BenchmarkRunner.shared
let results = runner.runFullBenchmark(scenarioCount: scenarioCount, verbose: true)

// Print console report
BenchmarkReport.printConsoleReport(results)

// Export reports
print("📝 Exporting reports...")
BenchmarkReport.exportMarkdownReport(results, filename: "benchmark_report_\(scenarioCount).md")
BenchmarkReport.exportJSONResults(results, filename: "benchmark_results_\(scenarioCount).json")

// Export dataset for reference
print("📊 Exporting dataset...")
let dataset = BenchmarkDataset.generate(count: min(scenarioCount, 1000))  // Export max 1000 for readability
BenchmarkDataset.exportToJSON(scenarios: dataset, filename: "benchmark_dataset_sample.json")

print("\n")
print("=" * 80)
print("✅ BENCHMARK COMPLETE")
print("=" * 80)
print("\nReports saved to:")
print("  • /tmp/benchmark_report_\(scenarioCount).md (for brand pitches)")
print("  • /tmp/benchmark_results_\(scenarioCount).json (raw data)")
print("  • /tmp/benchmark_dataset_sample.json (dataset sample)")
print("\n")

// Final summary
let accuracy = Double(results.correctPredictions) / Double(results.totalScenarios) * 100.0
let fpr = Double(results.falsePositives) / Double(results.falsePositives + results.trueNegatives) * 100.0

if accuracy > 90 && fpr < 10 {
    print("🎉 SDK IS PRODUCTION-READY!")
    print("   You can confidently pitch this to Ring, Nest, and other brands.\n")
} else if accuracy > 85 {
    print("⚠️  SDK IS MOSTLY READY")
    print("   Minor improvements needed before major brand pitches.\n")
} else {
    print("🚨 SDK NEEDS WORK")
    print("   Address accuracy and false positive issues before pitching.\n")
}

print("Next Steps:")
print("  1. Review /tmp/benchmark_report_\(scenarioCount).md")
print("  2. Analyze failure patterns in the report")
print("  3. If ready, use report in brand pitch decks")
print("  4. If not ready, iterate on AI and re-run benchmark\n")

// String extension
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}



