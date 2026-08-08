import Foundation

public enum CodexHookEvent: String, CaseIterable, Codable, Sendable {
    case sessionStart = "SessionStart"
    case userPromptSubmit = "UserPromptSubmit"
    case preToolUse = "PreToolUse"
    case permissionRequest = "PermissionRequest"
    case postToolUse = "PostToolUse"
    case stop = "Stop"
    case subagentStop = "SubagentStop"
}

public enum HookInstallationStatus: Sendable, Equatable {
    case notInstalled
    case installed(events: Set<String>, relayPath: String)
    case incomplete(events: Set<String>)
    case unreadable(String)
}

public struct HookInstallationReceipt: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let marker: String
    public let relayPath: String
    public let events: [String]
    public let installedAt: Date

    public init(relayPath: String, events: [String], installedAt: Date) {
        schemaVersion = 1
        marker = CodexHookInstaller.marker
        self.relayPath = relayPath
        self.events = events
        self.installedAt = installedAt
    }
}

public enum CodexHookInstallerError: Error, Sendable, Equatable {
    case malformedRoot
    case malformedHooks
    case malformedEvent(String)
    case validationFailed
}
