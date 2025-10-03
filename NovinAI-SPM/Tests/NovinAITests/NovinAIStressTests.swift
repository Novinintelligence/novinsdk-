import XCTest
@testable import NovinAI

final class NovinAIStressTests: XCTestCase {

    func testConcurrentRequests() {
        let ai = NovinAI()
        let payload = """
        {"systemMode":"away","events":[{"type":"motion","confidence":0.75,"timestamp":"2025-09-27T12:00:00Z"}]}
        """.data(using: .utf8)!

        let expectation = expectation(description: "Concurrent")
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.concurrentPerform(iterations: 500) { _ in
                _ = try? ai.process(json: payload)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 30.0)
    }
}
