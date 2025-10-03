#!/bin/bash

# NovinIntelligence SDK - Vigorous Test Runner
# Runs all test suites with detailed reporting and coverage analysis

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="intelligence"
SCHEME="intelligence"
TEST_RESULTS_DIR="$PROJECT_DIR/TestResults"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Create test results directory
mkdir -p "$TEST_RESULTS_DIR"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  NovinIntelligence SDK - Vigorous Test Suite Runner       ║${NC}"
echo -e "${BLUE}║  Timestamp: $(date)                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to run tests with specific filter
run_test_suite() {
    local suite_name=$1
    local test_filter=$2
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Running: $suite_name${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local result_file="$TEST_RESULTS_DIR/${suite_name}_${TIMESTAMP}.txt"
    
    if xcodebuild test \
        -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
        -only-testing:"${PROJECT_NAME}Tests/$test_filter" \
        2>&1 | tee "$result_file"; then
        echo -e "${GREEN}✓ $suite_name PASSED${NC}"
        return 0
    else
        echo -e "${RED}✗ $suite_name FAILED${NC}"
        return 1
    fi
}

# Track results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
declare -a FAILED_SUITE_NAMES

# Test Suites to run
echo -e "${BLUE}Starting comprehensive test execution...${NC}\n"

# 1. Core Innovation Tests
TOTAL_SUITES=$((TOTAL_SUITES + 1))
if run_test_suite "InnovationValidation" "InnovationValidationTests"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    FAILED_SUITE_NAMES+=("InnovationValidation")
fi
echo ""

# 2. Brand Integration Tests
TOTAL_SUITES=$((TOTAL_SUITES + 1))
if run_test_suite "BrandIntegration" "BrandIntegrationTests"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    FAILED_SUITE_NAMES+=("BrandIntegration")
fi
echo ""

# 3. Comprehensive Brand Tests
TOTAL_SUITES=$((TOTAL_SUITES + 1))
if run_test_suite "ComprehensiveBrand" "ComprehensiveBrandTests"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    FAILED_SUITE_NAMES+=("ComprehensiveBrand")
fi
echo ""

# 4. Temporal Dampening Tests
TOTAL_SUITES=$((TOTAL_SUITES + 1))
if run_test_suite "TemporalDampening" "TemporalDampeningTests"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    FAILED_SUITE_NAMES+=("TemporalDampening")
fi
echo ""

# 5. Edge Case Tests
TOTAL_SUITES=$((TOTAL_SUITES + 1))
if run_test_suite "EdgeCase" "EdgeCaseTests"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    FAILED_SUITE_NAMES+=("EdgeCase")
fi
echo ""

# 6. Enterprise Security Tests
TOTAL_SUITES=$((TOTAL_SUITES + 1))
if run_test_suite "EnterpriseSecurity" "EnterpriseSecurityTests"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    FAILED_SUITE_NAMES+=("EnterpriseSecurity")
fi
echo ""

# 7. Event Chain Tests
TOTAL_SUITES=$((TOTAL_SUITES + 1))
if run_test_suite "EventChain" "EventChainTests"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    FAILED_SUITE_NAMES+=("EventChain")
fi
echo ""

# 8. Motion Analysis Tests
TOTAL_SUITES=$((TOTAL_SUITES + 1))
if run_test_suite "MotionAnalysis" "MotionAnalysisTests"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    FAILED_SUITE_NAMES+=("MotionAnalysis")
fi
echo ""

# 9. Zone Classification Tests
TOTAL_SUITES=$((TOTAL_SUITES + 1))
if run_test_suite "ZoneClassification" "ZoneClassificationTests"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    FAILED_SUITE_NAMES+=("ZoneClassification")
fi
echo ""

# 10. Adaptability Tests
TOTAL_SUITES=$((TOTAL_SUITES + 1))
if run_test_suite "Adaptability" "AdaptabilityTests"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    FAILED_SUITE_NAMES+=("Adaptability")
fi
echo ""

# 11. Mental Model Tests
TOTAL_SUITES=$((TOTAL_SUITES + 1))
if run_test_suite "MentalModel" "MentalModelTests"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    FAILED_SUITE_NAMES+=("MentalModel")
fi
echo ""

# 12. Enterprise Feature Tests
TOTAL_SUITES=$((TOTAL_SUITES + 1))
if run_test_suite "EnterpriseFeature" "EnterpriseFeatureTests"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    FAILED_SUITE_NAMES+=("EnterpriseFeature")
fi
echo ""

# Generate Summary Report
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    TEST SUMMARY REPORT                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Total Test Suites:    ${BLUE}$TOTAL_SUITES${NC}"
echo -e "Passed:               ${GREEN}$PASSED_SUITES${NC}"
echo -e "Failed:               ${RED}$FAILED_SUITES${NC}"
echo ""

if [ $FAILED_SUITES -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              ✓ ALL TESTS PASSED SUCCESSFULLY!              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    SUCCESS_RATE="100%"
else
    echo -e "${RED}Failed Test Suites:${NC}"
    for suite in "${FAILED_SUITE_NAMES[@]}"; do
        echo -e "  ${RED}✗ $suite${NC}"
    done
    echo ""
    SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f%%\", ($PASSED_SUITES/$TOTAL_SUITES)*100}")
fi

echo ""
echo -e "Success Rate:         ${BLUE}$SUCCESS_RATE${NC}"
echo -e "Test Results:         ${BLUE}$TEST_RESULTS_DIR${NC}"
echo -e "Timestamp:            ${BLUE}$TIMESTAMP${NC}"
echo ""

# Generate JSON report
cat > "$TEST_RESULTS_DIR/summary_${TIMESTAMP}.json" << EOF
{
  "timestamp": "$TIMESTAMP",
  "total_suites": $TOTAL_SUITES,
  "passed": $PASSED_SUITES,
  "failed": $FAILED_SUITES,
  "success_rate": "$SUCCESS_RATE",
  "failed_suites": [$(printf '"%s",' "${FAILED_SUITE_NAMES[@]}" | sed 's/,$//')]
}
EOF

echo -e "${BLUE}JSON report saved to: $TEST_RESULTS_DIR/summary_${TIMESTAMP}.json${NC}"
echo ""

# Exit with appropriate code
if [ $FAILED_SUITES -eq 0 ]; then
    exit 0
else
    exit 1
fi
