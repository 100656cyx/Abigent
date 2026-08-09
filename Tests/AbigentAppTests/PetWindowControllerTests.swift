import XCTest
@testable import AbigentApp

@MainActor
final class PetWindowControllerTests: XCTestCase {
    func testConstructionDoesNotStartSwiftUIRendering() {
        let controller = PetWindowController()
        XCTAssertFalse(controller.isStarted)
    }

    func testStartIsIdempotent() {
        let controller = PetWindowController()
        controller.start(visible: false)
        controller.start(visible: false)
        XCTAssertTrue(controller.isStarted)
    }
}
