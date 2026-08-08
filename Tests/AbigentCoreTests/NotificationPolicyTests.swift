import Foundation
import XCTest
@testable import AbigentCore

final class NotificationPolicyTests: XCTestCase {
    func testWorkingNeverNotifies() {
        XCTAssertEqual(NotificationPolicy.decision(previous: .discovered, current: task(.working)), .none)
    }

    func testAttentionAndCompletionNotifyOnlyOnEntry() {
        XCTAssertEqual(NotificationPolicy.decision(previous: .working, current: task(.needsInput)), .attention)
        XCTAssertEqual(NotificationPolicy.decision(previous: .needsInput, current: task(.needsInput)), .none)
        XCTAssertEqual(NotificationPolicy.decision(previous: .working, current: task(.completed)), .completed)
    }

    func testMutedTasksNeverNotify() {
        var muted = task(.needsInput)
        muted.muted = true
        XCTAssertEqual(NotificationPolicy.decision(previous: .working, current: muted), .none)
    }

    private func task(_ state: TaskState) -> AgentTask {
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
            updatedAt: Date(timeIntervalSince1970: 1),
            completedAt: nil,
            muted: false
        )
    }
}
