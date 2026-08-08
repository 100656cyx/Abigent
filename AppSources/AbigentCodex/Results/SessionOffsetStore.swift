import Foundation

public actor SessionOffsetStore {
    private var offsets: [String: UInt64] = [:]

    public init() {}
    public func offset(for sessionID: String) -> UInt64 { offsets[sessionID] ?? 0 }
    public func commit(_ offset: UInt64, for sessionID: String) { offsets[sessionID] = offset }
}
