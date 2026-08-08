import AbigentCore
import Foundation

struct CodexHookPayload {
    let raw: [String: JSONValue]

    init?(_ value: JSONValue) {
        guard case let .object(raw) = value else { return nil }
        self.raw = raw
    }

    var sessionID: String? { string(["session_id", "thread_id", "conversation_id"]) }
    var threadID: String? { string(["thread_id", "session_id", "conversation_id"]) }
    var cwd: String? { string(["cwd", "project_dir", "workspace_path"]) }
    var prompt: String? { string(["prompt", "user_prompt", "message"]) }
    var toolName: String? { string(["tool_name", "tool", "name"]) }
    var permissionReason: String? { string(["reason", "question", "message"]) }
    var requestID: String? { string(["request_id", "permission_id", "id"]) }

    var choices: [AttentionChoice] {
        for key in ["options", "available_decisions", "choices"] {
            guard case let .array(values)? = raw[key] else { continue }
            return values.compactMap { value in
                switch value {
                case let .string(label): return .init(id: label, label: label)
                case let .object(object):
                    guard case let .string(label)? = object["label"] else { return nil }
                    let id: String
                    if case let .string(value)? = object["id"] { id = value } else { id = label }
                    return .init(id: id, label: label)
                default: return nil
                }
            }
        }
        return []
    }

    private func string(_ keys: [String]) -> String? {
        for key in keys {
            if case let .string(value)? = raw[key], !value.isEmpty { return value }
        }
        return nil
    }
}
