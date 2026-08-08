import AbigentCore
import AbigentHooks
import Foundation

public actor CodexHookNormalizer {
    private var sessionToTask: [String: String] = [:]

    public init() {}

    public func normalize(_ envelope: HookEnvelope) -> [ObservedAgentEvent] {
        guard envelope.source == .codex,
              envelope.schemaVersion == 1,
              let payload = CodexHookPayload(envelope.payload),
              let sourceTaskID = payload.threadID ?? envelope.sessionID
        else { return [] }
        if let session = payload.sessionID ?? envelope.sessionID {
            sessionToTask[session] = sourceTaskID
        }
        let resolvedID = (envelope.sessionID.flatMap { sessionToTask[$0] }) ?? sourceTaskID
        let id = GlobalTaskID(source: .codex, sourceTaskID: resolvedID)
        let events: [AgentEvent]

        switch envelope.event {
        case CodexHookEvent.sessionStart.rawValue:
            let task = AgentTask(
                id: id,
                source: .codex,
                sourceTaskID: resolvedID,
                projectName: payload.cwd.map { URL(fileURLWithPath: $0).lastPathComponent },
                title: payload.prompt?.prefix(120).description ?? "Codex Task",
                state: .discovered,
                attentionRequest: nil,
                result: nil,
                startedAt: nil,
                updatedAt: envelope.observedAt,
                completedAt: nil,
                muted: false,
                provenance: .hook,
                observedAt: envelope.observedAt
            )
            events = [.snapshot(task)]
        case CodexHookEvent.userPromptSubmit.rawValue:
            events = [.stateChanged(id: id, state: .working, updatedAt: envelope.observedAt)]
        case CodexHookEvent.preToolUse.rawValue, CodexHookEvent.postToolUse.rawValue:
            events = [.stateChanged(id: id, state: .working, updatedAt: envelope.observedAt)]
        case CodexHookEvent.permissionRequest.rawValue:
            let request = AttentionRequest(
                id: payload.requestID ?? "hook:\(resolvedID):\(envelope.observedAt.timeIntervalSince1970)",
                title: payload.toolName.map { "Codex 请求使用 \($0)" } ?? "Codex 需要操作",
                body: payload.permissionReason,
                choices: payload.choices
            )
            events = [.attention(id: id, request: request)]
        case CodexHookEvent.stop.rawValue:
            events = [.stateChanged(id: id, state: .completed, updatedAt: envelope.observedAt)]
        case CodexHookEvent.subagentStop.rawValue:
            events = []
        default:
            events = []
        }
        return events.map {
            ObservedAgentEvent(event: $0, provenance: .hook, observedAt: envelope.observedAt)
        }
    }
}
