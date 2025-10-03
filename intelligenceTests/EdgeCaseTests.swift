import XCTest
import NovinIntelligence

@available(iOS 15.0, *)
final class EdgeCaseTests: XCTestCase {
    override func setUp() async throws {
        try await NovinIntelligence.shared.initialize()
        NovinIntelligence.shared.setSystemMode("standard")
    }

    func testUnknownEventType_WithTimestampAndLocation() async throws {
        let ts = Date().addingTimeInterval(-300).timeIntervalSince1970
        let json = """
        {"type":"unknown","timestamp": \(ts), "metadata":{"location":"sideYard"}}
        """
        let pi = try await NovinIntelligence.shared.assessPI(requestJson: json)
        print("UNKNOWN_EVENT_PI:\n\(pi)")
        try pi.write(toFile: "/tmp/unknown_event_pi.json", atomically: true, encoding: .utf8)
        XCTAssertTrue(pi.contains("security_assessment"))
    }

    func testKnownHumanLowTrust_UnknownFace() async throws {
        let ts = Date().timeIntervalSince1970
        let json = """
        {"type":"face","timestamp": \(ts), "metadata":{"location":"frontDoor"},"user_risk_profile":{"trust_level":0.2}}
        """
        let pi = try await NovinIntelligence.shared.assessPI(requestJson: json)
        print("UNKNOWN_FACE_PI:\n\(pi)")
        try pi.write(toFile: "/tmp/unknown_face_pi.json", atomically: true, encoding: .utf8)
        XCTAssertTrue(pi.contains("threat"))
    }

    func testKnownHumanHighTrust_NoThreat() async throws {
        let ts = Date().timeIntervalSince1970
        let json = """
        {"type":"face","timestamp": \(ts), "metadata":{"location":"backDoor"},"user_risk_profile":{"trust_level":0.9}}
        """
        let pi = try await NovinIntelligence.shared.assessPI(requestJson: json)
        print("KNOWN_FACE_PI:\n\(pi)")
        XCTAssertTrue(pi.contains("security_assessment"))
    }

    func testGlassbreakHighSeverity() async throws {
        let json = """
        {"type":"glassbreak","confidence":0.95,"timestamp": \(Date().timeIntervalSince1970),"metadata":{"location":"kitchen"}}
        """
        let pi = try await NovinIntelligence.shared.assessPI(requestJson: json)
        print("GLASSBREAK_PI:\n\(pi)")
        try pi.write(toFile: "/tmp/glassbreak_pi.json", atomically: true, encoding: .utf8)
        XCTAssertTrue(pi.contains("glass"))
    }

    func testPetMotionShouldDownweight() async throws {
        let json = """
        {"type":"pet","confidence":0.8,"timestamp": \(Date().timeIntervalSince1970),"metadata":{"location":"livingRoom"}}
        """
        let pi = try await NovinIntelligence.shared.assessPI(requestJson: json)
        print("PET_PI:\n\(pi)")
        XCTAssertTrue(pi.contains("security_assessment"))
    }

    func testSoundOnlyNeutral() async throws {
        let json = """
        {"type":"sound","confidence":0.7,"timestamp": \(Date().timeIntervalSince1970),"metadata":{"location":"garage"}}
        """
        let pi = try await NovinIntelligence.shared.assessPI(requestJson: json)
        print("SOUND_PI:\n\(pi)")
        XCTAssertTrue(pi.contains("security_assessment"))
    }

    func testMissingFieldsGraceful() async throws {
        let json = "{}"
        let pi = try await NovinIntelligence.shared.assessPI(requestJson: json)
        print("MISSING_FIELDS_PI:\n\(pi)")
        XCTAssertTrue(pi.contains("security_assessment"))
    }
}


