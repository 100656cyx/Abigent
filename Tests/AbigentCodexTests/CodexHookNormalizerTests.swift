import AbigentCore
import AbigentHooks
import Foundation
import XCTest
@testable import AbigentCodex

final class CodexHookNormalizerTests: XCTestCase {
    func testPromptSubmitBecomesWorkingHookEvent() async throws {
        let events = await CodexHookNormalizer().normalize(envelope("UserPromptSubmit"))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.provenance, .hook)
        guard case let .stateChanged(_, state, _)? = events.first?.event else {
            return XCTFail("Expected state event")
        }
        XCTAssertEqual(state, .working)
    }

    func testPermissionRequestCreatesAttention() async throws {
        let events = await CodexHookNormalizer().normalize(envelope(
            "PermissionRequest",
            extra: ["tool_name": .string("shell"), "reason": .string("Run tests?")]
        ))
        guard case let .attention(_, request)? = events.first?.event else {
            return XCTFail("Expected attention event")
        }
        XCTAssertEqual(request.body, "Run tests?")
    }

    func testSubagentStopDoesNotCompleteParent() async {
        XCTAssertTrue(await CodexHookNormalizer().normalize(envelope("SubagentStop")).isEmpty)
    }

    private func envelope(_ event: String, extra: [String: JSONValue] = [:]) -> HookEnvelope {
        var payload: [String: JSONValue] = ["session_id": .string("00000000-0000-0000-0000-000000000001")]
        payload.merge(extra) { _, new in new }
        return HookEnvelope(
            source: .codex,
            event: event,
            sessionID: "00000000-0000-0000-0000-000000000001",
            observedAt: Date(timeIntervalSince1970: 42),
            payload: .object(payload)
        )
    }
}
