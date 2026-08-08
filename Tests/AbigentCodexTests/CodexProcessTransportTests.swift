import Foundation
import XCTest
@testable import AbigentCodex

final class CodexProcessTransportTests: XCTestCase {
    func testTransportDecodesOneJSONRPCObjectPerLine() async throws {
        let transport = CodexProcessTransport(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"method\":\"ready\",\"params\":{}}'"]
        )
        try await transport.start()
        var iterator = await transport.messages().makeAsyncIterator()
        guard case let .message(message)? = await iterator.next() else {
            return XCTFail("Expected one JSON-RPC message")
        }
        XCTAssertEqual(message.method, "ready")
        await transport.stop()
    }

    func testMalformedLineEmitsProtocolErrorWithoutPayload() async throws {
        let transport = CodexProcessTransport(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf 'not-json\\n'"]
        )
        try await transport.start()
        var iterator = await transport.messages().makeAsyncIterator()
        XCTAssertEqual(await iterator.next(), .protocolError)
        await transport.stop()
    }
}
