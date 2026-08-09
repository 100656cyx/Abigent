import CoreGraphics
import XCTest
@testable import AbigentCore

final class PetPlacementTests: XCTestCase {
    func testScaleIsClampedToSupportedRange() {
        XCTAssertEqual(PetPlacement(scale: 0.1).normalizedScale, 0.5)
        XCTAssertEqual(PetPlacement(scale: 2).normalizedScale, 1.5)
        XCTAssertEqual(PetPlacement(scale: 1.2).normalizedScale, 1.2)
    }

    func testPlacementClampsEveryEdgeToVisibleFrame() {
        let visible = CGRect(x: 100, y: 50, width: 1_000, height: 800)
        let petSize = CGSize(width: 190, height: 250)

        let low = PetPlacement(scale: 1, origin: CGPoint(x: -40, y: -20))
            .clamped(to: visible, petSize: petSize)
        XCTAssertEqual(low.origin, CGPoint(x: 100, y: 50))

        let high = PetPlacement(scale: 1.5, origin: CGPoint(x: 1_000, y: 700))
            .clamped(to: visible, petSize: petSize)
        XCTAssertEqual(high.origin.x, visible.maxX - petSize.width * 1.5)
        XCTAssertEqual(high.origin.y, visible.maxY - petSize.height * 1.5)
    }

    func testInBoundsPlacementIsPreserved() {
        let placement = PetPlacement(scale: 1, origin: CGPoint(x: 400, y: 300))
        XCTAssertEqual(
            placement.clamped(
                to: CGRect(x: 0, y: 0, width: 1_000, height: 800),
                petSize: CGSize(width: 190, height: 250)
            ),
            placement
        )
    }
}
