import AbigentCore
import Foundation

struct CodexThreadListResponse: Decodable {
    let data: [CodexThread]
    let nextCursor: String?
}

struct CodexThread: Decodable {
    let id: String
    let cwd: String
    let preview: String
    let name: String?
    let status: CodexThreadStatus
    let turns: [CodexTurn]
    let createdAt: Int64
    let updatedAt: Int64
}

struct CodexThreadStatus: Decodable {
    let type: String
    let activeFlags: [String]?
}

struct CodexTurn: Decodable {
    let id: String
    let status: String
    let items: [JSONValue]
    let startedAt: Int64?
    let completedAt: Int64?
}

struct CodexTurnNotification: Decodable {
    let threadId: String
    let turn: CodexTurn
}

struct CodexCommandApproval: Decodable {
    let threadId: String
    let turnId: String
    let itemId: String
    let command: String?
    let reason: String?
    let availableDecisions: [String]?
}

struct CodexUserInputRequest: Decodable {
    struct Question: Decodable {
        struct Option: Decodable {
            let label: String
            let description: String
        }
        let id: String
        let header: String
        let question: String
        let options: [Option]?
    }
    let threadId: String
    let turnId: String
    let itemId: String
    let isBlocking: Bool
    let questions: [Question]
}

extension JSONValue {
    func decoded<T: Decodable>(as type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(type, from: data)
    }

    var objectValue: [String: JSONValue]? {
        guard case let .object(value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }
}
