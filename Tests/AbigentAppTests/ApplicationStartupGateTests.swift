import XCTest
@testable import AbigentApp

final class ApplicationStartupGateTests: XCTestCase {
    func testBeginSucceedsOnlyOnce() {
        let gate = ApplicationStartupGate()
        XCTAssertTrue(gate.begin())
        XCTAssertFalse(gate.begin())
    }
}
