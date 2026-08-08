import AbigentCore
import Foundation
import XCTest
@testable import AbigentCodex

final class CodexMapperTests: XCTestCase {
    func testActiveThreadMapsToWorkingWithoutInventedResult() {
        let thread = CodexThread(
            id: "thread-1",
            cwd: "/tmp/vibe",
            preview: "Build Abigent",
            name: nil,
            status: .init(type: "active", activeFlags: []),
            turns: [],
            createdAt: 10,
            updatedAt: 20
        )
        let task = CodexMapper.task(from: thread)
        XCTAssertEqual(task.state, .working)
        XCTAssertEqual(task.id.rawValue, "codex:thread-1")
        XCTAssertNil(task.result)
    }

    func testCompletedTurnUsesOnlyExplicitAgentMessage() {
        let turn = CodexTurn(
            id: "turn-1",
            status: "completed",
            items: [.object(["type": .string("agentMessage"), "text": .string("Done. Tests were not reported.")])],
            startedAt: 10,
            completedAt: 20
        )
        let result = CodexMapper.result(from: turn)
        XCTAssertEqual(result?.summary, "Done. Tests were not reported.")
        XCTAssertNil(result?.tests)
        XCTAssertNil(result?.changedFiles)
    }

    func testCommandApprovalPreservesOpaqueRequestID() {
        let approval = CodexCommandApproval(
            threadId: "thread-1",
            turnId: "turn-1",
            itemId: "item-1",
            command: "swift test",
            reason: "Run project tests?",
            availableDecisions: ["accept", "decline"]
        )
        let request = CodexMapper.attention(from: approval, requestID: "i:42")
        XCTAssertEqual(request.id, "i:42")
        XCTAssertEqual(request.choices.map(\.id), ["accept", "decline"])
    }
}
