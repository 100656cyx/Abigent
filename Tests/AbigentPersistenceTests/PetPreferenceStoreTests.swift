import AbigentCore
import Foundation
import XCTest
@testable import AbigentPersistence

final class PetPreferenceStoreTests: XCTestCase {
    func testMissingPreferenceReturnsDefault() async {
        let fixture = Fixture()
        let placement = await fixture.store.load()
        XCTAssertEqual(placement, PetPlacement())
    }

    func testPlacementRoundTripsAndNormalizesScale() async throws {
        let fixture = Fixture()
        try await fixture.store.save(
            PetPlacement(scale: 4, origin: CGPoint(x: 321, y: 123))
        )
        let placement = await fixture.store.load()
        XCTAssertEqual(placement.scale, 1.5)
        XCTAssertEqual(placement.origin, CGPoint(x: 321, y: 123))
    }

    func testCorruptPreferenceReturnsDefault() async {
        let fixture = Fixture()
        fixture.defaults.set(Data("invalid".utf8), forKey: PetPreferenceStore.storageKey)
        let placement = await fixture.store.load()
        XCTAssertEqual(placement, PetPlacement())
    }

    private final class Fixture {
        let suiteName = "PetPreferenceStoreTests-\(UUID().uuidString)"
        let defaults: UserDefaults
        let store: PetPreferenceStore

        init() {
            defaults = UserDefaults(suiteName: suiteName)!
            store = PetPreferenceStore(defaults: defaults)
        }

        deinit { defaults.removePersistentDomain(forName: suiteName) }
    }
}
