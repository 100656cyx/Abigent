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
        let fixture = Fixture(initialData: Data("invalid".utf8))
        let placement = await fixture.store.load()
        XCTAssertEqual(placement, PetPlacement())
    }

    private final class Fixture {
        let suiteName = "PetPreferenceStoreTests-\(UUID().uuidString)"
        let store: PetPreferenceStore

        init(initialData: Data? = nil) {
            let defaults = UserDefaults(suiteName: suiteName)!
            if let initialData {
                defaults.set(initialData, forKey: PetPreferenceStore.storageKey)
            }
            store = PetPreferenceStore(defaults: defaults)
        }

        deinit { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
    }
}
