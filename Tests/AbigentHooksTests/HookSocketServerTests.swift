import AbigentCore
import Foundation
import XCTest
@testable import AbigentHooks

final class HookSocketServerTests: XCTestCase {
    func testEnvelopeRoundTrips() throws {
        let envelope = HookEnvelope(
            source: .codex,
            event: "Stop",
            sessionID: "session-1",
            observedAt: Date(timeIntervalSince1970: 42),
            payload: .object(["hook_event_name": .string("Stop")])
        )
        XCTAssertEqual(
            try JSONDecoder().decode(HookEnvelope.self, from: JSONEncoder().encode(envelope)),
            envelope
        )
    }

    func testStartCreatesPrivateSocketAndStopRemovesIt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let socket = directory.appendingPathComponent("bridge.sock")
        let server = HookSocketServer(socketURL: socket)
        try server.start()
        let permissions = try FileManager.default.attributesOfItem(atPath: socket.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
        server.stop()
        XCTAssertFalse(FileManager.default.fileExists(atPath: socket.path))
    }
}
