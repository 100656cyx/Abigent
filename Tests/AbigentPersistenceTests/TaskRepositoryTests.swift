import AbigentCore
import Foundation
import XCTest
@testable import AbigentPersistence

final class TaskRepositoryTests: XCTestCase {
    func testRoundTripAndNotificationDeduplication() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = try TaskRepository(databaseURL: url)
        let task = AgentTask(
            id: .init(source: .codex, sourceTaskID: "thread-1"), source: .codex,
            sourceTaskID: "thread-1", projectName: nil, title: "Task", state: .completed,
            attentionRequest: nil, result: nil, startedAt: nil, updatedAt: Date(timeIntervalSince1970: 1),
            completedAt: Date(timeIntervalSince1970: 1), muted: false
        )
        try await repository.upsert(task)
        let storedTasks = try await repository.allTasks()
        let firstNotification = try await repository.recordNotification(task: task)
        let duplicateNotification = try await repository.recordNotification(task: task)
        XCTAssertEqual(storedTasks, [task])
        XCTAssertTrue(firstNotification)
        XCTAssertFalse(duplicateNotification)
        try await repository.clearAll()
        let remainingTasks = try await repository.allTasks()
        XCTAssertEqual(remainingTasks, [])
    }
}
