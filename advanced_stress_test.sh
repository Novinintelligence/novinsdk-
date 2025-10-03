#!/bin/bash

# NovinIntelligence SDK - Advanced Stress Testing
# Tests SDK under extreme load conditions

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$PROJECT_DIR/StressTestResults"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

mkdir -p "$RESULTS_DIR"

echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║    NovinIntelligence SDK - Advanced Stress Testing        ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Test configurations
declare -a TEST_SCENARIOS=(
    "BURST:1000:10"           # 1000 requests in 10 seconds
    "SUSTAINED:10000:60"      # 10000 requests over 60 seconds
    "SPIKE:500:5"             # 500 requests in 5 seconds
    "GRADUAL:5000:120"        # 5000 requests over 2 minutes
)

run_stress_scenario() {
    local scenario=$1
    IFS=':' read -r type count duration <<< "$scenario"
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Stress Test: $type${NC}"
    echo -e "${YELLOW}Requests: $count | Duration: ${duration}s${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local result_file="$RESULTS_DIR/stress_${type}_${TIMESTAMP}.json"
    
    # Create Swift stress test runner
    cat > "$PROJECT_DIR/temp_stress_test.swift" << 'EOF'
import Foundation
import NovinIntelligence

@main
struct StressTest {
    static func main() async {
        let sdk = NovinIntelligence.shared
        try? await sdk.initialize()
        
        let requestCount = Int(CommandLine.arguments[1]) ?? 100
        let duration = Double(CommandLine.arguments[2]) ?? 10.0
        let delay = duration / Double(requestCount)
        
        var successCount = 0
        var failureCount = 0
        var totalTime: Double = 0
        var minTime: Double = .infinity
        var maxTime: Double = 0
        
        print("Starting stress test: \(requestCount) requests over \(duration)s")
        let startTime = Date()
        
        for i in 0..<requestCount {
            let requestStart = Date()
            
            let json = """
            {
                "type": "motion",
                "confidence": 0.85,
                "timestamp": \(Date().timeIntervalSince1970),
                "metadata": {
                    "location": "front_door",
                    "home_mode": "away"
                }
            }
            """
            
            do {
                let result = try await sdk.assess(requestJson: json)
                let requestTime = Date().timeIntervalSinceReferenceDate - requestStart.timeIntervalSinceReferenceDate
                totalTime += requestTime
                minTime = min(minTime, requestTime)
                maxTime = max(maxTime, requestTime)
                successCount += 1
            } catch {
                failureCount += 1
            }
            
            if i % 100 == 0 && i > 0 {
                print("Progress: \(i)/\(requestCount) requests")
            }
            
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        let totalDuration = Date().timeIntervalSince(startTime)
        let avgTime = totalTime / Double(successCount)
        
        let results: [String: Any] = [
            "total_requests": requestCount,
            "successful": successCount,
            "failed": failureCount,
            "total_duration_seconds": totalDuration,
            "average_time_ms": avgTime * 1000,
            "min_time_ms": minTime * 1000,
            "max_time_ms": maxTime * 1000,
            "requests_per_second": Double(requestCount) / totalDuration,
            "success_rate": Double(successCount) / Double(requestCount) * 100
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: results, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("\n=== RESULTS ===")
            print(jsonString)
        }
    }
}
EOF
    
    # Compile and run stress test
    echo -e "${BLUE}Compiling stress test...${NC}"
    if swiftc -o "$PROJECT_DIR/temp_stress_runner" \
        -I /Users/Ollie/novin_intelligence-main/Sources \
        -L /Users/Ollie/novin_intelligence-main/.build/debug \
        "$PROJECT_DIR/temp_stress_test.swift" 2>/dev/null; then
        
        echo -e "${BLUE}Running stress test...${NC}"
        "$PROJECT_DIR/temp_stress_runner" "$count" "$duration" | tee "$result_file"
        
        # Cleanup
        rm "$PROJECT_DIR/temp_stress_test.swift"
        rm "$PROJECT_DIR/temp_stress_runner"
        
        echo -e "${GREEN}✓ Stress test completed${NC}"
    else
        echo -e "${YELLOW}Note: Stress test requires compiled SDK${NC}"
        echo -e "${BLUE}Running XCTest-based stress test instead...${NC}"
        
        # Fallback to XCTest
        xcodebuild test \
            -project "$PROJECT_DIR/intelligence.xcodeproj" \
            -scheme "intelligence" \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
            -only-testing:"intelligenceTests/EdgeCaseTests" \
            2>&1 | grep -E "(Test|passed|failed)"
    fi
    
    echo ""
}

# Run all stress scenarios
for scenario in "${TEST_SCENARIOS[@]}"; do
    run_stress_scenario "$scenario"
    sleep 2  # Cool down between tests
done

# Memory leak detection
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Memory Leak Detection${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

xcodebuild test \
    -project "$PROJECT_DIR/intelligence.xcodeproj" \
    -scheme "intelligence" \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
    -enableAddressSanitizer YES \
    -enableThreadSanitizer YES \
    2>&1 | grep -E "(leak|sanitizer|Test)"

echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║              STRESS TESTING COMPLETED                      ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Results saved to: $RESULTS_DIR${NC}"
echo ""
