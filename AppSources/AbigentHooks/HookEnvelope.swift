import AbigentCore
import Foundation

public struct HookEnvelope: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let source: AgentKind
    public let event: String
    public let sessionID: String?
    public let observedAt: Date
    public let payload: JSONValue

    public init(
        schemaVersion: Int = 1,
        source: AgentKind,
        event: String,
        sessionID: String?,
        observedAt: Date,
        payload: JSONValue
    ) {
        self.schemaVersion = schemaVersion
        self.source = source
        self.event = event
        self.sessionID = sessionID
        self.observedAt = observedAt
        self.payload = payload
    }
}

public enum HookSocketError: Error, Sendable, Equatable {
    case pathTooLong
    case createFailed(Int32)
    case bindFailed(Int32)
    case listenFailed(Int32)
    case permissionFailed
}
