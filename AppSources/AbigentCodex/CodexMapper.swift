import AbigentCore
import Foundation

enum CodexMapper {
    static func task(from thread: CodexThread) -> AgentTask {
        let lastTurn = thread.turns.last
        return AgentTask(
            id: .init(source: .codex, sourceTaskID: thread.id),
            source: .codex,
            sourceTaskID: thread.id,
            projectName: URL(fileURLWithPath: thread.cwd).lastPathComponent,
            title: nonEmpty(thread.name) ?? nonEmpty(thread.preview) ?? "Codex Task",
            state: state(threadStatus: thread.status.type, lastTurnStatus: lastTurn?.status),
            attentionRequest: nil,
            result: lastTurn.flatMap(result(from:)),
            startedAt: lastTurn?.startedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            updatedAt: Date(timeIntervalSince1970: TimeInterval(thread.updatedAt)),
            completedAt: lastTurn?.completedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            muted: false
        )
    }

    static func state(threadStatus: String, lastTurnStatus: String?) -> TaskState {
        if threadStatus == "active" { return .working }
        if threadStatus == "systemError" { return .failed }
        switch lastTurnStatus {
        case "inProgress": return .working
        case "completed": return .completed
        case "failed": return .failed
        case "interrupted": return .cancelled
        default: return .discovered
        }
    }

    static func result(from turn: CodexTurn) -> TaskResult? {
        guard turn.status == "completed" || turn.status == "failed" else { return nil }
        let messages = turn.items.compactMap { item -> String? in
            guard let object = item.objectValue,
                  object["type"]?.stringValue == "agentMessage"
            else { return nil }
            return object["text"]?.stringValue
        }
        return TaskResult(
            summary: messages.last.map(firstSentence),
            changedFiles: changedFiles(from: turn.items),
            tests: nil,
            detail: messages.last
        )
    }

    static func attention(from approval: CodexCommandApproval, requestID: String) -> AttentionRequest {
        let decisions = approval.availableDecisions ?? ["accept", "decline"]
        return AttentionRequest(
            id: requestID,
            title: approval.reason ?? "Codex requests permission",
            body: approval.command,
            choices: decisions.map { AttentionChoice(id: $0, label: decisionLabel($0)) }
        )
    }

    static func attention(from request: CodexUserInputRequest, requestID: String) -> AttentionRequest {
        let question = request.questions.first
        return AttentionRequest(
            id: requestID,
            title: question?.header ?? "Codex needs input",
            body: question?.question,
            choices: question?.options?.map { .init(id: $0.label, label: $0.label) } ?? []
        )
    }

    private static func changedFiles(from items: [JSONValue]) -> [String]? {
        let paths = items.compactMap { item -> String? in
            guard let object = item.objectValue,
                  object["type"]?.stringValue == "fileChange"
            else { return nil }
            return object["path"]?.stringValue
        }
        return paths.isEmpty ? nil : paths
    }

    private static func decisionLabel(_ value: String) -> String {
        switch value {
        case "accept": return "允许"
        case "decline": return "拒绝"
        case "cancel": return "拒绝并停止"
        case "acceptForSession": return "本次会话允许"
        default: return value
        }
    }

    private static func firstSentence(_ value: String) -> String {
        let line = value.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? value
        return String(line.prefix(160))
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}
