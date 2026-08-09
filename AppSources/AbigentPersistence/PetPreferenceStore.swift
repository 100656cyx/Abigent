import AbigentCore
import Foundation

public actor PetPreferenceStore {
    public static let storageKey = "com.abigent.desktop.pet-placement"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> PetPlacement {
        guard let data = defaults.data(forKey: Self.storageKey),
              let placement = try? decoder.decode(PetPlacement.self, from: data)
        else { return PetPlacement() }
        return PetPlacement(scale: placement.normalizedScale, origin: placement.origin)
    }

    public func save(_ placement: PetPlacement) throws {
        let normalized = PetPlacement(
            scale: placement.normalizedScale,
            origin: placement.origin
        )
        defaults.set(try encoder.encode(normalized), forKey: Self.storageKey)
    }

    public func reset() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}
