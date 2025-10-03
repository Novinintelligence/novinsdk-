import XCTest
@testable import NovinIntelligence

/// Zone classification tests (P1.3 feature)
@available(iOS 15.0, macOS 12.0, *)
final class ZoneClassificationTests: XCTestCase {
    
    var classifier: ZoneClassifier!
    
    override func setUp() {
        classifier = ZoneClassifier()
    }
    
    // MARK: - Basic Classification
    
    func testEntryPointClassification() {
        let zone = classifier.classifyLocation("front_door")
        
        XCTAssertEqual(zone.name, "front_door")
        XCTAssertEqual(zone.type, .entry)
        XCTAssertTrue(zone.riskScore > 0.6, "Entry points should be high risk")
        print("✅ Front door: risk=\(String(format: "%.0f", zone.riskScore * 100))%")
    }
    
    func testPerimeterClassification() {
        let zone = classifier.classifyLocation("backyard")
        
        XCTAssertEqual(zone.type, .perimeter)
        XCTAssertTrue(zone.riskScore > 0.5, "Perimeter should be elevated risk")
        print("✅ Backyard: risk=\(String(format: "%.0f", zone.riskScore * 100))%")
    }
    
    func testInteriorClassification() {
        let zone = classifier.classifyLocation("living_room")
        
        XCTAssertEqual(zone.type, .interior)
        XCTAssertTrue(zone.riskScore < 0.5, "Interior should be lower risk when home")
        print("✅ Living room: risk=\(String(format: "%.0f", zone.riskScore * 100))%")
    }
    
    func testPublicClassification() {
        let zone = classifier.classifyLocation("street")
        
        XCTAssertEqual(zone.type, .public)
        XCTAssertTrue(zone.riskScore < 0.4, "Public areas should be lower risk")
        print("✅ Street: risk=\(String(format: "%.0f", zone.riskScore * 100))%")
    }
    
    // MARK: - Alias Matching
    
    func testAliasMatching() {
        // "frontdoor" should match "front_door"
        let zone1 = classifier.classifyLocation("frontdoor")
        XCTAssertEqual(zone1.name, "front_door")
        
        // "back" should match "back_door"
        let zone2 = classifier.classifyLocation("back")
        XCTAssertEqual(zone2.name, "back_door")
        
        print("✅ Alias matching works")
    }
    
    // MARK: - Partial Matching
    
    func testPartialMatching() {
        // "front_door_camera" should match "front_door"
        let zone = classifier.classifyLocation("front_door_camera")
        XCTAssertEqual(zone.name, "front_door")
        
        print("✅ Partial matching works")
    }
    
    // MARK: - Unknown Fallback
    
    func testUnknownFallback() {
        let zone = classifier.classifyLocation("random_location_xyz")
        
        XCTAssertEqual(zone.name, "unknown")
        XCTAssertEqual(zone.riskScore, 0.5, "Unknown should default to medium risk")
        print("✅ Unknown fallback: risk=\(String(format: "%.0f", zone.riskScore * 100))%")
    }
    
    // MARK: - Risk Score Helpers
    
    func testGetRiskScore() {
        let riskScore = classifier.getRiskScore(for: "back_door")
        XCTAssertTrue(riskScore > 0.7, "Back door should be high risk")
        print("✅ Back door risk score: \(String(format: "%.0f", riskScore * 100))%")
    }
    
    func testIsEntryPoint() {
        XCTAssertTrue(classifier.isEntryPoint("front_door"))
        XCTAssertFalse(classifier.isEntryPoint("backyard"))
        print("✅ Entry point detection works")
    }
    
    func testIsPerimeter() {
        XCTAssertTrue(classifier.isPerimeter("backyard"))
        XCTAssertTrue(classifier.isPerimeter("porch"))
        XCTAssertFalse(classifier.isPerimeter("living_room"))
        print("✅ Perimeter detection works")
    }
    
    // MARK: - Zone Escalation
    
    func testPerimeterToEntryEscalation() {
        let sequence = ["backyard", "back_door"]
        let escalation = classifier.calculateZoneEscalation(sequence)
        
        XCTAssertTrue(escalation > 1.5, "Perimeter → Entry should escalate")
        print("✅ Perimeter → Entry escalation: \(String(format: "%.1f", escalation))x")
    }
    
    func testEntryToInteriorEscalation() {
        let sequence = ["front_door", "living_room"]
        let escalation = classifier.calculateZoneEscalation(sequence)
        
        XCTAssertTrue(escalation > 1.8, "Entry → Interior (breach) should escalate significantly")
        print("✅ Entry → Interior escalation: \(String(format: "%.1f", escalation))x")
    }
    
    func testMultiplePerimeterEscalation() {
        let sequence = ["backyard", "side_yard", "front_yard"]
        let escalation = classifier.calculateZoneEscalation(sequence)
        
        XCTAssertTrue(escalation > 1.0, "Multiple perimeter zones (prowling) should escalate")
        print("✅ Prowling escalation: \(String(format: "%.1f", escalation))x")
    }
    
    func testNoEscalation() {
        let sequence = ["living_room"]
        let escalation = classifier.calculateZoneEscalation(sequence)
        
        XCTAssertEqual(escalation, 1.0, "Single zone should not escalate")
        print("✅ No false escalation")
    }
    
    // MARK: - Risk Ordering
    
    func testRiskOrdering() {
        let backDoor = classifier.getRiskScore(for: "back_door")
        let backyard = classifier.getRiskScore(for: "backyard")
        let livingRoom = classifier.getRiskScore(for: "living_room")
        let street = classifier.getRiskScore(for: "street")
        
        XCTAssertTrue(backDoor > backyard, "Entry should be higher risk than perimeter")
        XCTAssertTrue(backyard > livingRoom, "Perimeter should be higher risk than interior")
        XCTAssertTrue(livingRoom > street, "Interior should be higher risk than public")
        
        print("✅ Risk ordering: entry > perimeter > interior > public")
    }
}



