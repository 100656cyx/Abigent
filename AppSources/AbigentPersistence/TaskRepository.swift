import AbigentCore
import Foundation

public actor TaskRepository {
    private let database: SQLiteDatabase
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(databaseURL: URL) throws {
        database = try SQLiteDatabase(url: databaseURL)
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    public func upsert(_ task: AgentTask) throws {
        try database.upsertTask(
            id: task.id.rawValue,
            updatedAt: task.updatedAt.timeIntervalSince1970,
            payload: encoder.encode(task)
        )
    }

    public func allTasks() throws -> [AgentTask] {
        try database.taskPayloads().map { try decoder.decode(AgentTask.self, from: $0) }
    }

    public func recordNotification(task: AgentTask) throws -> Bool {
        let key = "\(task.id.rawValue):\(task.state.rawValue):\(task.updatedAt.timeIntervalSince1970)"
        return try database.insertReceipt(key: key)
    }

    public func clearAll() throws { try database.clearAll() }
}
