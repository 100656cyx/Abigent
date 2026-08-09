import AbigentCore
import Foundation
import XCTest
@testable import AbigentCodex

final class CodexResultRecoveryCoordinatorTests: XCTestCase {
    func testRetriesThenDeliversOnce() async throws {
        let attempts = Counter()
        let delivered = Counter()
        let coordinator = CodexResultRecoveryCoordinator(delays: [.zero, .zero, .zero]) { _, date in
            let attempt = await attempts.increment()
            if attempt < 3 { throw CodexResultExtractorError.resultNotYetAvailable }
            return TaskResult(summary: "完成", detail: "最终回复", returnedAt: date)
        }

        await coordinator.recover(sessionID: UUID().uuidString, stopObservedAt: .now) { _ in
            _ = await delivered.increment()
        }
        try await waitUntil { await delivered.value == 1 }

        let attemptCount = await attempts.value
        let deliveryCount = await delivered.value
        XCTAssertEqual(attemptCount, 3)
        XCTAssertEqual(deliveryCount, 1)
    }

    func testNewGenerationCancelsOlderSameSessionRecovery() async throws {
        let delivered = Messages()
        let sessionID = UUID().uuidString
        let coordinator = CodexResultRecoveryCoordinator(delays: [.milliseconds(50)]) { _, date in
            TaskResult(summary: nil, detail: date.timeIntervalSince1970.description, returnedAt: date)
        }

        await coordinator.recover(sessionID: sessionID, stopObservedAt: Date(timeIntervalSince1970: 1)) {
            await delivered.append($0.detail ?? "")
        }
        await coordinator.recover(sessionID: sessionID, stopObservedAt: Date(timeIntervalSince1970: 2)) {
            await delivered.append($0.detail ?? "")
        }
        try await waitUntil { await delivered.values.count == 1 }

        let values = await delivered.values
        XCTAssertEqual(values, ["2.0"])
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping @Sendable () async -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Condition was not met before timeout")
    }
}

private actor Counter {
    private(set) var value = 0
    func increment() -> Int { value += 1; return value }
}

private actor Messages {
    private(set) var values: [String] = []
    func append(_ value: String) { values.append(value) }
}
