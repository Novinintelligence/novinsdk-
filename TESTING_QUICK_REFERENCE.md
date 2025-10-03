# NovinIntelligence SDK - Testing Quick Reference

## 🚀 One-Command Testing

```bash
# Interactive menu (RECOMMENDED)
./test_orchestrator.sh

# Run everything
./run_all_tests.sh

# Watch and auto-test
./continuous_test_monitor.sh

# Stress testing
./advanced_stress_test.sh

# Coverage analysis
./generate_test_coverage.sh

# Regression validation
./regression_test_suite.sh
```

---

## 📋 Common Commands

### Run All Tests
```bash
./run_all_tests.sh
```

### Run Specific Suite
```bash
xcodebuild test \
  -project intelligence.xcodeproj \
  -scheme intelligence \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
  -only-testing:intelligenceTests/InnovationValidationTests
```

### Quick Validation (Core Tests Only)
```bash
xcodebuild test \
  -project intelligence.xcodeproj \
  -scheme intelligence \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
  -only-testing:intelligenceTests/InnovationValidationTests \
  -only-testing:intelligenceTests/EnterpriseSecurityTests
```

---

## 🎯 Test Suites

| Suite | Command Flag |
|-------|-------------|
| Innovation Validation | `InnovationValidationTests` |
| Brand Integration | `BrandIntegrationTests` |
| Comprehensive Brand | `ComprehensiveBrandTests` |
| Temporal Dampening | `TemporalDampeningTests` |
| Enterprise Security | `EnterpriseSecurityTests` |
| Event Chain | `EventChainTests` |
| Motion Analysis | `MotionAnalysisTests` |
| Zone Classification | `ZoneClassificationTests` |
| Edge Cases | `EdgeCaseTests` |
| Adaptability | `AdaptabilityTests` |
| Mental Model | `MentalModelTests` |
| Enterprise Features | `EnterpriseFeatureTests` |

---

## 📊 Results Locations

```
TestResults/          - Full test suite results
CoverageReports/      - Code coverage analysis
RegressionResults/    - Regression test data
StressTestResults/    - Performance/load test data
```

---

## ⚡ Quick Checks

### Before Commit
```bash
./run_all_tests.sh && ./regression_test_suite.sh
```

### Before PR
```bash
./run_all_tests.sh
./generate_test_coverage.sh
./regression_test_suite.sh
```

### Before Release
```bash
./test_orchestrator.sh
# Choose option 7 (Complete Audit)
```

---

## 🔧 Troubleshooting

### Tests won't run
```bash
xcode-select --install
```

### Simulator not found
```bash
xcrun simctl list devices
# Update device name in scripts
```

### fswatch not installed
```bash
brew install fswatch
```

---

## 📈 Performance Targets

| Metric | Target |
|--------|--------|
| Average Response | <30ms |
| Max Response | <50ms |
| Requests/sec | >100 |
| Success Rate | 100% |
| Test Coverage | >90% |

---

## ✅ Daily Workflow

1. **Start continuous monitor**
   ```bash
   ./continuous_test_monitor.sh &
   ```

2. **Make changes** - tests run automatically

3. **Before commit**
   ```bash
   ./run_all_tests.sh
   ```

4. **Weekly**
   ```bash
   ./test_orchestrator.sh
   # Option 7: Complete Audit
   ```

---

## 🎓 Learn More

See `TESTING_GUIDE.md` for comprehensive documentation.
