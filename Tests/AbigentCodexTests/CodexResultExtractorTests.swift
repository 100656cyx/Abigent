import Foundation
import XCTest
@testable import AbigentCodex

final class CodexResultExtractorTests: XCTestCase {
    func testExtractsLastCompletedTurnAgentMessage() async throws {
        let fixture = try Fixture(lines: [
            event("task_started"),
            event("agent_message", extra: ["message": "第一轮完成"]),
            event("task_complete"),
            event("task_started"),
            event("agent_message", extra: ["message": "最终结论\n更多细节"]),
            event("task_complete")
        ])
        let returnedAt = Date(timeIntervalSince1970: 42)
        let result = try await fixture.extractor.extract(sessionID: fixture.sessionID, stopObservedAt: returnedAt)
        XCTAssertEqual(result.summary, "最终结论")
        XCTAssertEqual(result.detail, "最终结论\n更多细节")
        XCTAssertEqual(result.returnedAt, returnedAt)
    }

    private static func event(_ type: String, extra: [String: Any] = [:]) -> [String: Any] {
        ["type": "event_msg", "payload": ["type": type].merging(extra) { _, new in new }]
    }

    private final class Fixture {
        let sessionID = "019fe19b-6f4d-7b60-930b-1c6546d9a12e"
        let directory: URL
        let extractor: CodexResultExtractor

        init(lines: [[String: Any]]) throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent("rollout-\(sessionID).jsonl")
            let data = try lines.map { try JSONSerialization.data(withJSONObject: $0) + Data([0x0A]) }
                .reduce(into: Data()) { $0.append($1) }
            try data.write(to: file)
            extractor = CodexResultExtractor(sessionsRoot: directory)
        }

        deinit { try? FileManager.default.removeItem(at: directory) }
    }
}
