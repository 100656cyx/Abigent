import Foundation
import XCTest
@testable import AbigentCore

final class TaskReducerTests: XCTestCase {
    func testOlderEventCannotReplaceNewerState() throws {
        let current = task(state: .completed, updatedAt: 20)
        let event = AgentEvent.stateChanged(
            id: current.id,
            state: .working,
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        XCTAssertEqual(try TaskReducer.reduce(current: current, event: event), current)
    }

    func testAttentionStoresRequestAndMovesToNeedsInput() throws {
        let current = task(state: .working, updatedAt: 10)
        let request = AttentionRequest(
            id: "approval-1",
            title: "Run tests?",
            body: nil,
            choices: [.init(id: "yes", label: "Allow")]
        )
        let next = try TaskReducer.reduce(
            current: current,
            event: .attention(id: current.id, request: request)
        )
        XCTAssertEqual(next.state, .needsInput)
        XCTAssertEqual(next.attentionRequest, request)
    }

    func testHookEventWinsOverLaterRecoveryEvent() throws {
        var current = task(state: .working, updatedAt: 20)
        current.provenance = .hook
        current.observedAt = Date(timeIntervalSince1970: 20)
        let recovery = ObservedAgentEvent(
            event: .stateChanged(
                id: current.id,
                state: .discovered,
                updatedAt: Date(timeIntervalSince1970: 30)
            ),
            provenance: .sessionRecovery,
            observedAt: Date(timeIntervalSince1970: 30)
        )

        XCTAssertEqual(try TaskReducer.reduce(current: current, observed: recovery), current)
    }

    func testOlderHookEventIsIdempotent() throws {
        var current = task(state: .completed, updatedAt: 20)
        current.provenance = .hook
        current.observedAt = Date(timeIntervalSince1970: 20)
        let duplicate = ObservedAgentEvent(
            event: .stateChanged(
                id: current.id,
                state: .working,
                updatedAt: Date(timeIntervalSince1970: 10)
            ),
            provenance: .hook,
            observedAt: Date(timeIntervalSince1970: 10)
        )

        XCTAssertEqual(try TaskReducer.reduce(current: current, observed: duplicate), current)
    }

    func testResultReturnTimeRoundTrips() throws {
        let result = TaskResult(
            summary: "Done",
            changedFiles: nil,
            tests: nil,
            detail: "Done",
            returnedAt: Date(timeIntervalSince1970: 42)
        )

        let encoded = try JSONEncoder().encode(result)
        XCTAssertEqual(try JSONDecoder().decode(TaskResult.self, from: encoded), result)
    }

    private func task(state: TaskState, updatedAt: TimeInterval) -> AgentTask {
        AgentTask(
            id: .init(source: .codex, sourceTaskID: "thread-1"),
            source: .codex,
            sourceTaskID: "thread-1",
            projectName: nil,
            title: "Task",
            state: state,
            attentionRequest: nil,
            result: nil,
            startedAt: nil,
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            completedAt: nil,
            muted: false
        )
    }
}
