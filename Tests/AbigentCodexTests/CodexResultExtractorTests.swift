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

    func testExtractsStoppedTurnBeforeTaskCompleteIsWritten() async throws {
        let fixture = try Fixture(lines: [
            event("task_started"),
            event("agent_message", extra: ["message": "已落盘的最终回复"])
        ])

        let result = try await fixture.extractor.extract(
            sessionID: fixture.sessionID,
            stopObservedAt: Date(timeIntervalSince1970: 84)
        )

        XCTAssertEqual(result.detail, "已落盘的最终回复")
    }

    func testDoesNotReturnPreviousTurnAfterNewTurnStarts() async throws {
        let fixture = try Fixture(lines: [
            event("task_started"),
            event("agent_message", extra: ["message": "上一轮回复"]),
            event("task_complete"),
            event("task_started")
        ])

        do {
            _ = try await fixture.extractor.extract(
                sessionID: fixture.sessionID,
                stopObservedAt: Date(timeIntervalSince1970: 126)
            )
            XCTFail("Expected a pending result instead of the previous turn")
        } catch {
            XCTAssertEqual(error as? CodexResultExtractorError, .resultNotYetAvailable)
        }
    }

    func testStopTimestampKeepsRecoveryOnCompletedTurnAfterNewTurnStarts() async throws {
        let fixture = try Fixture(lines: [
            event("task_started", timestamp: "2026-08-09T12:56:00.000Z"),
            event(
                "agent_message",
                timestamp: "2026-08-09T12:56:24.085Z",
                extra: ["message": "本轮最终结论\n完整内容"]
            ),
            event("task_complete", timestamp: "2026-08-09T12:56:24.791Z"),
            event("task_started", timestamp: "2026-08-09T12:56:46.900Z")
        ])

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let result = try await fixture.extractor.extract(
            sessionID: fixture.sessionID,
            stopObservedAt: try XCTUnwrap(formatter.date(
                from: "2026-08-09T12:56:24.825Z"
            ))
        )

        XCTAssertEqual(result.summary, "本轮最终结论")
        XCTAssertEqual(result.detail, "本轮最终结论\n完整内容")
    }

    func testSkipsMalformedJSONLines() async throws {
        let fixture = try Fixture(lines: [
            event("task_started"),
            event("agent_message", extra: ["message": "有效回复"]),
            event("task_complete")
        ], prefix: Data("not-json\n".utf8))

        let result = try await fixture.extractor.extract(
            sessionID: fixture.sessionID,
            stopObservedAt: Date(timeIntervalSince1970: 168)
        )

        XCTAssertEqual(result.detail, "有效回复")
    }

    private func event(
        _ type: String,
        timestamp: String? = nil,
        extra: [String: Any] = [:]
    ) -> [String: Any] {
        var root: [String: Any] = [
            "type": "event_msg",
            "payload": ["type": type].merging(extra) { _, new in new }
        ]
        root["timestamp"] = timestamp
        return root
    }

    private final class Fixture {
        let sessionID = "00000000-0000-0000-0000-000000000001"
        let directory: URL
        let extractor: CodexResultExtractor

        init(lines: [[String: Any]], prefix: Data = Data()) throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent("rollout-\(sessionID).jsonl")
            var data = prefix
            let encoded = try lines.map { try JSONSerialization.data(withJSONObject: $0) + Data([0x0A]) }
                .reduce(into: Data()) { $0.append($1) }
            data.append(encoded)
            try data.write(to: file)
            extractor = CodexResultExtractor(sessionsRoot: directory)
        }

        deinit { try? FileManager.default.removeItem(at: directory) }
    }
}
