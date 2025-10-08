import XCTest
@testable import NovinIntelligence
import struct NovinIntelligence.Predicate

final class MirrorTests: XCTestCase {
    func testMirrorMatch() {
        let mirror = EnvironmentalMirror()
        let predicted: Set<Predicate> = [Predicate("motion_detected"), Predicate("high_confidence")]
        let observed: Set<Predicate> = [Predicate("motion_detected"), Predicate("high_confidence")]
        let diff = mirror.diff(predicted: predicted, observed: observed)
        XCTAssertTrue(diff.missingPredicates.isEmpty)
        XCTAssertTrue(diff.unexpectedPredicates.isEmpty)
    }

    func testMirrorMissing() {
        let mirror = EnvironmentalMirror()
        let predicted: Set<Predicate> = [Predicate("glassbreak_detected")]
        let observed: Set<Predicate> = []
        let diff = mirror.diff(predicted: predicted, observed: observed)
        XCTAssertEqual(diff.missingPredicates.count, 1)
        XCTAssertEqual(diff.missingPredicates.first?.name, "glassbreak_detected")
        XCTAssertTrue(diff.unexpectedPredicates.isEmpty)
    }

    func testMirrorUnexpected() {
        let mirror = EnvironmentalMirror()
        let predicted: Set<Predicate> = []
        let observed: Set<Predicate> = [Predicate("perimeter")]
        let diff = mirror.diff(predicted: predicted, observed: observed)
        XCTAssertEqual(diff.unexpectedPredicates.count, 1)
        XCTAssertEqual(diff.unexpectedPredicates.first?.name, "perimeter")
        XCTAssertTrue(diff.missingPredicates.isEmpty)
    }

    func testUpdaterProposals() {
        let updater = SymbolicUpdater()
        let diff = EnvironmentalMirror.Diff(
            missingPredicates: [Predicate("glassbreak_detected")],
            unexpectedPredicates: [Predicate("stage_observe")]
        )
        let updates = updater.proposeUpdates(diff: diff)
        XCTAssertEqual(updates.count, 2)
        XCTAssertTrue(updates[0].description.contains("missing predicates"))
        XCTAssertTrue(updates[1].description.contains("unexpected predicates"))
    }

    func testMirrorTelemetryRecord() {
        MirrorTelemetry.shared.record(missing: 2, unexpected: 1, updates: 1, durationMs: 0.5)
        XCTAssertEqual(MirrorTelemetry.shared.lastMissing, 2)
        XCTAssertEqual(MirrorTelemetry.shared.lastUnexpected, 1)
        XCTAssertEqual(MirrorTelemetry.shared.lastUpdates, 1)
    }
}
