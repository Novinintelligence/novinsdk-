#!/usr/bin/env swift

import Foundation

// Simple test runner to validate innovation
print("\n" + String(repeating: "=", count: 80))
print("🚀 NOVIN INTELLIGENCE: INNOVATION VALIDATION TEST")
print(String(repeating: "=", count: 80) + "\n")

// Test scenarios
let scenarios = [
    ("Amazon Delivery 10 AM", #"{"timestamp": \#(Date().timeIntervalSince1970), "home_mode": "away", "events": [{"type": "doorbell_chime", "confidence": 0.95}, {"type": "motion", "confidence": 0.88}]}"#, "Should be LOW/STANDARD"),
    ("Burglar 10 AM", #"{"timestamp": \#(Date().timeIntervalSince1970), "home_mode": "away", "events": [{"type": "doorbell_chime", "confidence": 0.92}, {"type": "motion", "confidence": 0.95, "metadata": {"duration": 120}}, {"type": "door", "confidence": 0.88}], "crime_context": {"crime_rate_24h": 0.65}}"#, "Should be ELEVATED/CRITICAL"),
    ("Night Prowler 2 AM", #"{"timestamp": \#(Date().timeIntervalSince1970 - 21600), "home_mode": "away", "events": [{"type": "motion", "confidence": 0.92, "metadata": {"location": "backyard", "duration": 180}}]}"#, "Should be ELEVATED/CRITICAL"),
    ("Pet Cat 3 PM", #"{"timestamp": \#(Date().timeIntervalSince1970), "home_mode": "away", "events": [{"type": "pet", "confidence": 0.88}]}"#, "Should be LOW"),
    ("Glass Break", #"{"timestamp": \#(Date().timeIntervalSince1970), "home_mode": "away", "events": [{"type": "glassbreak", "confidence": 0.92}]}"#, "Should be CRITICAL"),
]

print("📊 RUNNING \(scenarios.count) INNOVATION TESTS:\n")

for (index, scenario) in scenarios.enumerated() {
    print("\(index + 1). \(scenario.0)")
    print("   Expected: \(scenario.2)")
    print("   JSON: \(String(scenario.1.prefix(80)))...")
    print("")
}

print(String(repeating: "=", count: 80))
print("✅ INNOVATION TEST SUITE CREATED")
print("📋 To run full tests, use Xcode test suite: InnovationValidationTests")
print(String(repeating: "=", count: 80) + "\n")



