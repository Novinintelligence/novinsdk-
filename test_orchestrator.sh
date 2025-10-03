#!/bin/bash

# NovinIntelligence SDK - Master Test Orchestrator
# Interactive menu for running different test configurations

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

clear

echo -e "${CYAN}${BOLD}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    NovinIntelligence SDK - Test Orchestrator v2.0           ║
║                                                              ║
║    Vigorous Testing Suite for Enterprise AI Security        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${BLUE}Select a testing mode:${NC}"
echo ""
echo -e "${GREEN}  1)${NC} Quick Test          - Run core tests only (~2 min)"
echo -e "${GREEN}  2)${NC} Full Test Suite    - Run all 12 test suites (~5 min)"
echo -e "${GREEN}  3)${NC} Continuous Monitor - Watch files and auto-test"
echo -e "${GREEN}  4)${NC} Stress Test        - Load testing and performance"
echo -e "${GREEN}  5)${NC} Coverage Report    - Generate code coverage analysis"
echo -e "${GREEN}  6)${NC} Regression Test    - Validate no breaking changes"
echo -e "${GREEN}  7)${NC} Complete Audit     - Run everything (full validation)"
echo -e "${GREEN}  8)${NC} Custom Test        - Select specific test suite"
echo ""
echo -e "${YELLOW}  9)${NC} View Test History"
echo -e "${YELLOW} 10)${NC} Clean Test Results"
echo ""
echo -e "${RED}  0)${NC} Exit"
echo ""
echo -n "Enter your choice [0-10]: "

read choice

case $choice in
    1)
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}Running Quick Test (Core Validation)${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        xcodebuild test \
            -project intelligence.xcodeproj \
            -scheme intelligence \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
            -only-testing:intelligenceTests/InnovationValidationTests \
            -only-testing:intelligenceTests/EnterpriseSecurityTests
        
        echo ""
        echo -e "${GREEN}✓ Quick test completed${NC}"
        ;;
        
    2)
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}Running Full Test Suite (All 12 Suites)${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        ./run_all_tests.sh
        ;;
        
    3)
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}Starting Continuous Test Monitor${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        if ! command -v fswatch &> /dev/null; then
            echo -e "${RED}Error: fswatch not installed${NC}"
            echo -e "${YELLOW}Install with: brew install fswatch${NC}"
            exit 1
        fi
        
        ./continuous_test_monitor.sh
        ;;
        
    4)
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}Running Advanced Stress Tests${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        ./advanced_stress_test.sh
        ;;
        
    5)
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}Generating Code Coverage Report${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        ./generate_test_coverage.sh
        ;;
        
    6)
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}Running Regression Test Suite${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        ./regression_test_suite.sh
        ;;
        
    7)
        echo ""
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${MAGENTA}${BOLD}COMPLETE AUDIT - Running All Validation${NC}"
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        echo -e "${BLUE}[1/4] Running full test suite...${NC}"
        ./run_all_tests.sh
        
        echo ""
        echo -e "${BLUE}[2/4] Generating coverage report...${NC}"
        ./generate_test_coverage.sh
        
        echo ""
        echo -e "${BLUE}[3/4] Running regression tests...${NC}"
        ./regression_test_suite.sh
        
        echo ""
        echo -e "${BLUE}[4/4] Running stress tests...${NC}"
        ./advanced_stress_test.sh
        
        echo ""
        echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${MAGENTA}║              COMPLETE AUDIT FINISHED                         ║${NC}"
        echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${GREEN}All validation completed successfully!${NC}"
        echo ""
        echo -e "${BLUE}Review results in:${NC}"
        echo -e "  • TestResults/"
        echo -e "  • CoverageReports/"
        echo -e "  • RegressionResults/"
        echo -e "  • StressTestResults/"
        ;;
        
    8)
        echo ""
        echo -e "${CYAN}Select test suite to run:${NC}"
        echo ""
        echo "  1) InnovationValidationTests"
        echo "  2) BrandIntegrationTests"
        echo "  3) ComprehensiveBrandTests"
        echo "  4) TemporalDampeningTests"
        echo "  5) EnterpriseSecurityTests"
        echo "  6) EventChainTests"
        echo "  7) MotionAnalysisTests"
        echo "  8) ZoneClassificationTests"
        echo "  9) EdgeCaseTests"
        echo " 10) AdaptabilityTests"
        echo " 11) MentalModelTests"
        echo " 12) EnterpriseFeatureTests"
        echo ""
        echo -n "Enter suite number [1-12]: "
        
        read suite_choice
        
        case $suite_choice in
            1) SUITE="InnovationValidationTests" ;;
            2) SUITE="BrandIntegrationTests" ;;
            3) SUITE="ComprehensiveBrandTests" ;;
            4) SUITE="TemporalDampeningTests" ;;
            5) SUITE="EnterpriseSecurityTests" ;;
            6) SUITE="EventChainTests" ;;
            7) SUITE="MotionAnalysisTests" ;;
            8) SUITE="ZoneClassificationTests" ;;
            9) SUITE="EdgeCaseTests" ;;
            10) SUITE="AdaptabilityTests" ;;
            11) SUITE="MentalModelTests" ;;
            12) SUITE="EnterpriseFeatureTests" ;;
            *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
        esac
        
        echo ""
        echo -e "${CYAN}Running $SUITE...${NC}"
        echo ""
        
        xcodebuild test \
            -project intelligence.xcodeproj \
            -scheme intelligence \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
            -only-testing:intelligenceTests/$SUITE
        ;;
        
    9)
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}Test History${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        if [ -d "TestResults" ]; then
            echo -e "${BLUE}Recent Test Runs:${NC}"
            ls -lt TestResults/summary_*.json 2>/dev/null | head -10 | while read -r line; do
                file=$(echo "$line" | awk '{print $NF}')
                if [ -f "$file" ]; then
                    echo ""
                    echo -e "${YELLOW}$(basename "$file")${NC}"
                    cat "$file" | grep -E "(timestamp|total_suites|passed|failed|success_rate)" | sed 's/^/  /'
                fi
            done
        else
            echo -e "${YELLOW}No test history found${NC}"
        fi
        
        echo ""
        ;;
        
    10)
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}Clean Test Results${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${RED}This will delete all test results, coverage reports, and stress test data.${NC}"
        echo -n "Are you sure? [y/N]: "
        
        read confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -rf TestResults CoverageReports RegressionResults StressTestResults DerivedData
            echo ""
            echo -e "${GREEN}✓ All test results cleaned${NC}"
        else
            echo ""
            echo -e "${BLUE}Cancelled${NC}"
        fi
        ;;
        
    0)
        echo ""
        echo -e "${BLUE}Exiting...${NC}"
        exit 0
        ;;
        
    *)
        echo ""
        echo -e "${RED}Invalid choice. Please select 0-10.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Done!${NC}"
echo ""
echo -e "${BLUE}Run './test_orchestrator.sh' again for more options${NC}"
echo ""
