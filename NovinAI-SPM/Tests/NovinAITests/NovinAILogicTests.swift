import XCTest
@testable import NovinAI

final class NovinAILogicTests: XCTestCase {

    private func fixture(_ name: String) -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
        return try! Data(contentsOf: url)
    }

    func testAwayMotionEscalation() throws {
        let ai = NovinAI()
        let data = fixture("away_motion")
        let result = try ai.process(json: data)
        XCTAssertEqual(result["threatLevel"] as? String, "ELEVATED")
        XCTAssertGreaterThan(result["confidence"] as? Double ?? 0.0, 0.5)
    }

    func testFalseAlarmPet() throws {
        let ai = NovinAI()
        let data = fixture("pet_false_alarm")
        let result = try ai.process(json: data)
        XCTAssertEqual(result["threatLevel"] as? String, "IGNORE")
    }

    func testInvalidJSON() {
        let ai = NovinAI()
        let invalid = "{".data(using: .utf8)!
        XCTAssertThrowsError(try ai.process(json: invalid)) { error in
            XCTAssertEqual(error as? NovinAIError, .invalidPayload)
        }
    }
}
