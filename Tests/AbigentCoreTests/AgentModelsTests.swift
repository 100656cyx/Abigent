import Foundation
import XCTest
@testable import AbigentCore

final class AgentModelsTests: XCTestCase {
    func testAgentTaskRoundTripsWithoutLosingSourceIdentity() throws {
        let task = AgentTask(
            id: .init(source: .codex, sourceTaskID: "thread-1"),
            source: .codex,
            sourceTaskID: "thread-1",
            projectName: "vibe",
            title: "Build Abigent",
            state: .working,
            attentionRequest: nil,
            result: nil,
            startedAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20),
            completedAt: nil,
            muted: false
        )

        let decoded = try JSONDecoder().decode(
            AgentTask.self,
            from: JSONEncoder().encode(task)
        )

        XCTAssertEqual(decoded, task)
        XCTAssertEqual(decoded.id.rawValue, "codex:thread-1")
    }
}
