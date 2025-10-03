import XCTest
@testable import NovinIntelligence

@available(iOS 15.0, macOS 12.0, *)
final class MathRulesPipelineTests: XCTestCase {

    func testInitializeAndAssessCriticalVsBenign() async throws {
        // Initialize once
        try await NovinIntelligence.shared.initialize()

        // Critical scenario: away + glassbreak + high crime
        let criticalJson = """
        {
          "timestamp": \(Date().timeIntervalSince1970),
          "home_mode": "away",
          "events": [{"type": "glassbreak", "confidence": 0.98}],
          "crime_context": {"crime_rate_24h": 0.45}
        }
        """
        let critical = try await NovinIntelligence.shared.assess(requestJson: criticalJson)
        XCTAssertTrue(critical.threatLevel == .elevated || critical.threatLevel == .critical)
        XCTAssertTrue((0.0...1.0).contains(critical.confidence))

        // Benign scenario: home + pet + low crime
        let benignJson = """
        {
          "timestamp": \(Date().timeIntervalSince1970),
          "home_mode": "home",
          "events": [{"type": "pet", "confidence": 0.70}],
          "crime_context": {"crime_rate_24h": 0.02}
        }
        """
        let benign = try await NovinIntelligence.shared.assess(requestJson: benignJson)
        XCTAssertTrue(benign.threatLevel == .low || benign.threatLevel == .standard)
        XCTAssertTrue((0.0...1.0).contains(benign.confidence))
    }

    func testInvalidJsonThrows() async {
        let invalid = "{ invalid json }"
        do {
            _ = try await NovinIntelligence.shared.assess(requestJson: invalid)
            XCTFail("Expected error for invalid JSON")
        } catch {
            // Expected
        }
    }
}
