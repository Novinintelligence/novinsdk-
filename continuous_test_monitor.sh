#!/bin/bash

# NovinIntelligence SDK - Continuous Test Monitor
# Watches for file changes and automatically runs relevant tests

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_DIR="/Users/Ollie/novin_intelligence-main/Sources/NovinIntelligence"
TEST_DIR="$PROJECT_DIR/intelligenceTests"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     NovinIntelligence SDK - Continuous Test Monitor       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Monitoring directories:${NC}"
echo -e "  • SDK: $SDK_DIR"
echo -e "  • Tests: $TEST_DIR"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop monitoring${NC}"
echo ""

# Check if fswatch is installed
if ! command -v fswatch &> /dev/null; then
    echo -e "${RED}Error: fswatch is not installed${NC}"
    echo -e "${YELLOW}Install with: brew install fswatch${NC}"
    exit 1
fi

# Function to run quick validation
run_quick_tests() {
    local changed_file=$1
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}File changed: $(basename "$changed_file")${NC}"
    echo -e "${YELLOW}Running quick validation tests...${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Determine which test suite to run based on file
    local test_suite=""
    
    if [[ "$changed_file" == *"Security"* ]]; then
        test_suite="EnterpriseSecurityTests"
    elif [[ "$changed_file" == *"EventChain"* ]]; then
        test_suite="EventChainTests"
    elif [[ "$changed_file" == *"Motion"* ]]; then
        test_suite="MotionAnalysisTests"
    elif [[ "$changed_file" == *"Zone"* ]]; then
        test_suite="ZoneClassificationTests"
    elif [[ "$changed_file" == *"Temporal"* ]]; then
        test_suite="TemporalDampeningTests"
    else
        # Run core innovation tests for general changes
        test_suite="InnovationValidationTests"
    fi
    
    echo -e "${BLUE}Running test suite: $test_suite${NC}\n"
    
    if xcodebuild test \
        -project "$PROJECT_DIR/intelligence.xcodeproj" \
        -scheme "intelligence" \
        -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
        -only-testing:"intelligenceTests/$test_suite" \
        2>&1 | grep -E "(Test Suite|Test Case|passed|failed|error)"; then
        echo -e "\n${GREEN}✓ Tests PASSED${NC}"
    else
        echo -e "\n${RED}✗ Tests FAILED${NC}"
    fi
    
    echo -e "${CYAN}Waiting for next change...${NC}\n"
}

# Export function for use in subshell
export -f run_quick_tests
export PROJECT_DIR
export RED GREEN YELLOW BLUE CYAN NC

# Watch for changes in SDK and test directories
fswatch -0 -r -e ".*" -i "\\.swift$" "$SDK_DIR" "$TEST_DIR" | while read -d "" file; do
    run_quick_tests "$file"
done
