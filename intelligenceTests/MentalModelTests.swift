import XCTest
import NovinIntelligence

@available(iOS 15.0, *)
final class MentalModelTests: XCTestCase {
    
    func testMentalModelPetScenario() async throws {
        let sdk = NovinIntelligence.shared
        try await sdk.initialize()
        
        // Test pet motion scenario - should trigger "Family Routine Activity" mental model
        let petJson = """
        {
            "type": "pet",
            "confidence": 0.8,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "livingRoom"
            },
            "home_mode": "home"
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: petJson)
        print("MENTAL_MODEL_PET_PI:\n\(pi)")
        
        // Should contain mental model reasoning
        XCTAssertTrue(pi.contains("security_assessment"))
        XCTAssertTrue(pi.contains("pet"))
    }
    
    func testMentalModelGlassbreakScenario() async throws {
        let sdk = NovinIntelligence.shared
        try await sdk.initialize()
        
        // Test glassbreak scenario - should trigger "Nighttime Intrusion Pattern" mental model
        let glassbreakJson = """
        {
            "type": "glassbreak",
            "confidence": 0.95,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "kitchen"
            },
            "home_mode": "away"
        }
        """
        
        let pi = try await sdk.assessPI(requestJson: glassbreakJson)
        print("MENTAL_MODEL_GLASSBREAK_PI:\n\(pi)")
        
        // Should contain mental model reasoning
        XCTAssertTrue(pi.contains("security_assessment"))
        XCTAssertTrue(pi.contains("glassbreak"))
    }
}


