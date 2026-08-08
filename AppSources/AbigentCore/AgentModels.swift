import Foundation

public enum AgentKind: String, Codable, Sendable, Equatable, Hashable {
    case codex
    case traeCN
}

public struct GlobalTaskID: RawRepresentable, Codable, Sendable, Equatable, Hashable {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }

    public init(source: AgentKind, sourceTaskID: String) {
        self.rawValue = "\(source.rawValue):\(sourceTaskID)"
    }
}

public enum TaskState: String, Codable, Sendable, Equatable, Hashable {
    case discovered, working, needsInput, completed, failed, cancelled, connectionUnknown
}

public enum EventProvenance: Int, Codable, Sendable, Equatable, Comparable {
    case accessibilityFallback = 0
    case sessionRecovery = 1
    case appServer = 2
    case hook = 3

    public static func < (lhs: EventProvenance, rhs: EventProvenance) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct AttentionChoice: Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

public struct AttentionRequest: Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let body: String?
    public let choices: [AttentionChoice]

    public init(id: String, title: String, body: String?, choices: [AttentionChoice]) {
        self.id = id
        self.title = title
        self.body = body
        self.choices = choices
    }
}

public struct TestSummary: Codable, Sendable, Equatable {
    public let passed: Int
    public let failed: Int
    public let skipped: Int

    public init(passed: Int, failed: Int, skipped: Int) {
        self.passed = passed
        self.failed = failed
        self.skipped = skipped
    }
}

public struct TaskResult: Codable, Sendable, Equatable {
    public let summary: String?
    public let changedFiles: [String]?
    public let tests: TestSummary?
    public let detail: String?
    public let returnedAt: Date?

    public init(
        summary: String?,
        changedFiles: [String]?,
        tests: TestSummary?,
        detail: String?,
        returnedAt: Date? = nil
    ) {
        self.summary = summary
        self.changedFiles = changedFiles
        self.tests = tests
        self.detail = detail
        self.returnedAt = returnedAt
    }
}

public struct AgentTask: Codable, Sendable, Equatable, Identifiable {
    public let id: GlobalTaskID
    public let source: AgentKind
    public let sourceTaskID: String
    public var projectName: String?
    public var title: String
    public var state: TaskState
    public var attentionRequest: AttentionRequest?
    public var result: TaskResult?
    public var startedAt: Date?
    public var updatedAt: Date
    public var completedAt: Date?
    public var muted: Bool
    public var provenance: EventProvenance?
    public var observedAt: Date?

    public init(
        id: GlobalTaskID,
        source: AgentKind,
        sourceTaskID: String,
        projectName: String?,
        title: String,
        state: TaskState,
        attentionRequest: AttentionRequest?,
        result: TaskResult?,
        startedAt: Date?,
        updatedAt: Date,
        completedAt: Date?,
        muted: Bool,
        provenance: EventProvenance? = nil,
        observedAt: Date? = nil
    ) {
        self.id = id
        self.source = source
        self.sourceTaskID = sourceTaskID
        self.projectName = projectName
        self.title = title
        self.state = state
        self.attentionRequest = attentionRequest
        self.result = result
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.muted = muted
        self.provenance = provenance
        self.observedAt = observedAt
    }
}

public enum ConnectionState: Codable, Sendable, Equatable {
    case disconnected, connecting, connected
    case incompatible(version: String)
    case failed(message: String)
}

public enum AgentEvent: Codable, Sendable, Equatable {
    case snapshot(AgentTask)
    case stateChanged(id: GlobalTaskID, state: TaskState, updatedAt: Date)
    case attention(id: GlobalTaskID, request: AttentionRequest)
    case result(id: GlobalTaskID, result: TaskResult)
    case connectionChanged(ConnectionState)
}

public struct ObservedAgentEvent: Codable, Sendable, Equatable {
    public let event: AgentEvent
    public let provenance: EventProvenance
    public let observedAt: Date

    public init(event: AgentEvent, provenance: EventProvenance, observedAt: Date) {
        self.event = event
        self.provenance = provenance
        self.observedAt = observedAt
    }
}

public enum UserResponse: Codable, Sendable, Equatable {
    case choice(id: String)
    case text(String)
}
