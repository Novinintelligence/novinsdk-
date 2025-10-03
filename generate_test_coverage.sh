#!/bin/bash

# NovinIntelligence SDK - Test Coverage Report Generator
# Generates detailed code coverage reports with HTML output

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COVERAGE_DIR="$PROJECT_DIR/CoverageReports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DERIVED_DATA="$PROJECT_DIR/DerivedData"

mkdir -p "$COVERAGE_DIR"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    NovinIntelligence SDK - Coverage Report Generator      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Clean previous build
echo -e "${BLUE}Cleaning previous builds...${NC}"
xcodebuild clean \
    -project "$PROJECT_DIR/intelligence.xcodeproj" \
    -scheme "intelligence" \
    > /dev/null 2>&1

# Run tests with code coverage enabled
echo -e "${BLUE}Running tests with code coverage enabled...${NC}"
echo ""

xcodebuild test \
    -project "$PROJECT_DIR/intelligence.xcodeproj" \
    -scheme "intelligence" \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
    -derivedDataPath "$DERIVED_DATA" \
    -enableCodeCoverage YES \
    2>&1 | grep -E "(Test Suite|Test Case|passed|failed|Testing|Executed)"

echo ""
echo -e "${BLUE}Generating coverage report...${NC}"

# Find the coverage data
XCRESULT_PATH=$(find "$DERIVED_DATA" -name "*.xcresult" | head -n 1)

if [ -z "$XCRESULT_PATH" ]; then
    echo -e "${RED}Error: Could not find test results${NC}"
    exit 1
fi

echo -e "${BLUE}Found test results: $XCRESULT_PATH${NC}"

# Export coverage data
COVERAGE_JSON="$COVERAGE_DIR/coverage_${TIMESTAMP}.json"
xcrun xccov view --report --json "$XCRESULT_PATH" > "$COVERAGE_JSON" 2>/dev/null || true

# Generate human-readable report
COVERAGE_TXT="$COVERAGE_DIR/coverage_${TIMESTAMP}.txt"

echo "NovinIntelligence SDK - Code Coverage Report" > "$COVERAGE_TXT"
echo "Generated: $(date)" >> "$COVERAGE_TXT"
echo "========================================" >> "$COVERAGE_TXT"
echo "" >> "$COVERAGE_TXT"

# Parse and display coverage
if [ -f "$COVERAGE_JSON" ]; then
    echo -e "${GREEN}Coverage data exported successfully${NC}"
    
    # Extract key metrics using xcrun xccov
    xcrun xccov view --report "$XCRESULT_PATH" >> "$COVERAGE_TXT" 2>/dev/null || true
    
    # Display summary
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Coverage Summary${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Show top of coverage report
    head -n 30 "$COVERAGE_TXT" | tail -n 20
    
    echo ""
    echo -e "${BLUE}Full report saved to: $COVERAGE_TXT${NC}"
    echo -e "${BLUE}JSON data saved to: $COVERAGE_JSON${NC}"
else
    echo -e "${YELLOW}Warning: Could not generate JSON coverage data${NC}"
fi

# Generate HTML report using xccov if available
echo ""
echo -e "${BLUE}Attempting to generate HTML report...${NC}"

# Check if we can generate HTML
if command -v xcov &> /dev/null; then
    echo -e "${GREEN}xcov found, generating HTML report...${NC}"
    xcov --scheme intelligence \
         --project "$PROJECT_DIR/intelligence.xcodeproj" \
         --output_directory "$COVERAGE_DIR/html_${TIMESTAMP}" \
         --json_report \
         --markdown_report
    
    echo -e "${GREEN}✓ HTML report generated${NC}"
    echo -e "${BLUE}Open: $COVERAGE_DIR/html_${TIMESTAMP}/index.html${NC}"
else
    echo -e "${YELLOW}Note: Install xcov for HTML reports: gem install xcov${NC}"
fi

# Generate coverage badge/summary
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Test Suite Coverage Summary${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Count test files and test methods
TEST_FILES=$(find "$PROJECT_DIR/intelligenceTests" -name "*.swift" | wc -l | tr -d ' ')
TEST_METHODS=$(grep -r "func test" "$PROJECT_DIR/intelligenceTests" | wc -l | tr -d ' ')
SDK_FILES=$(find "/Users/Ollie/novin_intelligence-main/Sources/NovinIntelligence" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')

echo -e "Test Files:           ${GREEN}$TEST_FILES${NC}"
echo -e "Test Methods:         ${GREEN}$TEST_METHODS${NC}"
echo -e "SDK Files:            ${BLUE}$SDK_FILES${NC}"
echo -e "Tests per SDK File:   ${CYAN}$(awk "BEGIN {printf \"%.1f\", $TEST_METHODS/$SDK_FILES}")${NC}"

# Create summary JSON
cat > "$COVERAGE_DIR/summary_${TIMESTAMP}.json" << EOF
{
  "timestamp": "$TIMESTAMP",
  "test_files": $TEST_FILES,
  "test_methods": $TEST_METHODS,
  "sdk_files": $SDK_FILES,
  "tests_per_file": $(awk "BEGIN {printf \"%.2f\", $TEST_METHODS/$SDK_FILES}"),
  "coverage_report": "coverage_${TIMESTAMP}.txt",
  "coverage_json": "coverage_${TIMESTAMP}.json"
}
EOF

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           COVERAGE REPORT GENERATION COMPLETE              ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Reports directory: $COVERAGE_DIR${NC}"
echo ""
