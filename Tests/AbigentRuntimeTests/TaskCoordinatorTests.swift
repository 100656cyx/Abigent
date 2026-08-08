import AbigentCore
import AbigentPersistence
import AbigentRuntime
import Foundation
import XCTest

private actor RuntimeFakeConnector: AgentConnector {
    nonisolated let kind = AgentKind.codex
    private let stream: AsyncStream<AgentEvent>
    private let continuation: AsyncStream<AgentEvent>.Continuation
    private let initial: AgentTask

    init(initial: AgentTask) {
        self.initial = initial
        let pair = AsyncStream<AgentEvent>.makeStream()
        stream = pair.stream
        continuation = pair.continuation
    }
    func connect() async throws {}
    func disconnect() async {}
    func initialSnapshot() async throws -> [AgentTask] { [initial] }
    func events() async -> AsyncStream<AgentEvent> { stream }
    func respond(taskID: String, requestID: String, response: UserResponse) async throws {}
    func cancel(taskID: String) async throws {}
    func continueTask(taskID: String, prompt: String) async throws {}
    func sourceURL(taskID: String) async -> URL? { nil }
    func emit(_ event: AgentEvent) { continuation.yield(event) }
}

final class TaskCoordinatorTests: XCTestCase {
    func testCompletionProducesOneNotificationIntent() async throws {
        let task = AgentTask(
            id: .init(source: .codex, sourceTaskID: "thread-1"), source: .codex,
            sourceTaskID: "thread-1", projectName: nil, title: "Task", state: .working,
            attentionRequest: nil, result: nil, startedAt: nil, updatedAt: Date(timeIntervalSince1970: 1),
            completedAt: nil, muted: false
        )
        let connector = RuntimeFakeConnector(initial: task)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = TaskCoordinator(connector: connector, repository: try TaskRepository(databaseURL: url))
        try await coordinator.start()
        var iterator = await coordinator.notifications().makeAsyncIterator()
        await connector.emit(.stateChanged(
            id: task.id, state: .completed, updatedAt: Date(timeIntervalSince1970: 2)
        ))
        let intent = await iterator.next()
        XCTAssertEqual(intent?.decision, .completed)
        await coordinator.stop()
    }
}
