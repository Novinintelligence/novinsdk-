import XCTest
@testable import NovinIntelligence

/// Enterprise security & validation tests (P0 features)
@available(iOS 15.0, macOS 12.0, *)
final class EnterpriseSecurityTests: XCTestCase {
    
    var sdk: NovinIntelligence!
    
    override func setUpWithError() throws {
        sdk = NovinIntelligence.shared
        Task {
            try await sdk.initialize()
        }
    }
    
    // MARK: - Input Validation Tests
    
    func testInputTooLarge() async throws {
        // Create 200KB JSON (exceeds 100KB limit)
        let largeString = String(repeating: "a", count: 200_000)
        let json = """
        {
            "type": "motion",
            "timestamp": \(Date().timeIntervalSince1970),
            "large_field": "\(largeString)"
        }
        """
        
        do {
            _ = try await sdk.assess(requestJson: json)
            XCTFail("Should have thrown input too large error")
        } catch let error as InputValidator.ValidationError {
            switch error {
            case .inputTooLarge:
                print("✅ Correctly rejected oversized input")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testInvalidJSON() async throws {
        let badJson = "{this is not valid json"
        
        do {
            _ = try await sdk.assess(requestJson: badJson)
            XCTFail("Should have thrown invalid JSON error")
        } catch {
            print("✅ Correctly rejected invalid JSON: \(error)")
        }
    }
    
    func testMaliciouslyDeepNesting() async throws {
        // Create deeply nested JSON (>10 levels)
        var nested = "\"value\""
        for _ in 0..<15 {
            nested = "{\"nested\": \(nested)}"
        }
        let json = """
        {
            "type": "motion",
            "timestamp": \(Date().timeIntervalSince1970),
            "deep": \(nested)
        }
        """
        
        do {
            _ = try await sdk.assess(requestJson: json)
            XCTFail("Should have thrown suspicious input error")
        } catch let error as InputValidator.ValidationError {
            print("✅ Correctly rejected deeply nested JSON: \(error)")
        }
    }
    
    func testSuspiciousLongStrings() async throws {
        let longLocation = String(repeating: "x", count: 20_000)
        let json = """
        {
            "type": "motion",
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "\(longLocation)"
            }
        }
        """
        
        do {
            _ = try await sdk.assess(requestJson: json)
            XCTFail("Should have thrown suspicious input error")
        } catch let error as InputValidator.ValidationError {
            print("✅ Correctly rejected long string: \(error)")
        }
    }
    
    // MARK: - Rate Limiting Tests
    
    func testRateLimiting() async throws {
        // Reset rate limiter
        sdk.resetRateLimiter()
        
        let validJson = """
        {
            "type": "motion",
            "timestamp": \(Date().timeIntervalSince1970),
            "confidence": 0.5
        }
        """
        
        // Send 150 requests rapidly (should hit 100 req limit)
        var successCount = 0
        var rateLimitedCount = 0
        
        for _ in 0..<150 {
            do {
                _ = try await sdk.assess(requestJson: validJson)
                successCount += 1
            } catch let error as InputValidator.ValidationError {
                if case .rateLimitExceeded = error {
                    rateLimitedCount += 1
                }
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
        
        print("✅ Rate Limiting: \(successCount) succeeded, \(rateLimitedCount) rate-limited")
        XCTAssertTrue(rateLimitedCount > 0, "Should have rate-limited some requests")
        XCTAssertTrue(successCount < 150, "Should not have allowed all requests")
    }
    
    // MARK: - Health Monitoring Tests
    
    func testHealthMonitoring() async throws {
        let health = sdk.getSystemHealth()
        
        print("📊 System Health:")
        print(health.description)
        
        XCTAssertTrue(health.totalAssessments >= 0)
        XCTAssertTrue(health.averageProcessingTimeMs >= 0)
        XCTAssertTrue(health.rateLimit.utilizationPercent >= 0)
        XCTAssertTrue(health.rateLimit.utilizationPercent <= 100)
        
        // Status should be healthy or degraded (not emergency)
        XCTAssertNotEqual(health.status, .emergency)
    }
    
    func testHealthMonitoringAfterError() async throws {
        // Cause an error
        do {
            _ = try await sdk.assess(requestJson: "invalid")
        } catch {
            // Expected
        }
        
        let health = sdk.getSystemHealth()
        XCTAssertTrue(health.errorCount > 0, "Should have recorded error")
    }
    
    // MARK: - Graceful Degradation Tests
    
    func testEmergencyMode() async throws {
        sdk.setMode(.emergency)
        
        let json = """
        {
            "type": "motion",
            "timestamp": \(Date().timeIntervalSince1970),
            "confidence": 0.9
        }
        """
        
        let result = try await sdk.assess(requestJson: json)
        
        // In emergency mode, should always return standard threat
        XCTAssertEqual(result.threatLevel, .standard)
        XCTAssertTrue(result.reasoning.contains("Emergency mode"))
        
        print("✅ Emergency mode returned safe fallback: \(result.threatLevel.rawValue)")
        
        // Reset to full mode
        sdk.setMode(.full)
    }
    
    func testMinimalMode() async throws {
        sdk.setMode(.minimal)
        
        let json = """
        {
            "type": "motion",
            "timestamp": \(Date().timeIntervalSince1970),
            "confidence": 0.9,
            "metadata": {
                "location": "front_door"
            }
        }
        """
        
        let result = try await sdk.assess(requestJson: json)
        
        // In minimal mode, should still work but without advanced features
        XCTAssertNotNil(result)
        print("✅ Minimal mode assessment: \(result.threatLevel.rawValue)")
        
        // Reset to full mode
        sdk.setMode(.full)
    }
    
    // MARK: - SDK Version Tests
    
    func testSDKVersion() {
        let version = NovinIntelligence.sdkVersion
        XCTAssertTrue(version.contains("enterprise"))
        print("✅ SDK Version: \(version)")
    }
}



