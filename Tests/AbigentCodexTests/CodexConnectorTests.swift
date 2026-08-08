import Foundation
import XCTest
@testable import AbigentCodex

private actor FakeTransport: CodexTransporting {
    private(set) var calls: [String] = []
    private let stream = AsyncStream<CodexTransportEvent> { _ in }

    func start() async throws { calls.append("start") }
    func messages() async -> AsyncStream<CodexTransportEvent> { stream }
    func send(method: String, params: JSONValue) async throws -> JSONValue {
        calls.append(method)
        if method == "initialize" { return .object([:]) }
        if method == "thread/list" { return .object(["data": .array([]), "nextCursor": .null]) }
        return .object([:])
    }
    func notify(method: String, params: JSONValue) async throws { calls.append(method) }
    func respond(id: JSONRPCID, result: JSONValue) async throws { calls.append("respond") }
    func stop() async { calls.append("stop") }
    func recordedCalls() -> [String] { calls }
}

final class CodexConnectorTests: XCTestCase {
    func testConnectInitializesBeforeSnapshot() async throws {
        let transport = FakeTransport()
        let connector = CodexConnector(transport: transport)
        try await connector.connect()
        let tasks = try await connector.initialSnapshot()
        XCTAssertEqual(tasks, [])
        XCTAssertEqual(await transport.recordedCalls(), ["start", "initialize", "initialized", "thread/list"])
        await connector.disconnect()
    }
}
