import AbigentCore
import Foundation
import OSLog

public actor CodexResultRecoveryCoordinator {
    public typealias Extract = @Sendable (String, Date) async throws -> TaskResult
    public typealias Deliver = @Sendable (TaskResult) async -> Void

    private struct Recovery {
        let generation: UUID
        let task: Task<Void, Never>
    }

    private struct RecoveryKey: Hashable {
        let sessionID: String
        let stopObservedAt: Date
    }

    private static let defaultDelays: [Duration] = [
        .zero,
        .milliseconds(100),
        .milliseconds(250),
        .milliseconds(500),
        .seconds(1),
        .seconds(2),
        .seconds(4),
        .seconds(7),
        .seconds(10),
        .milliseconds(5_150)
    ]

    private let extract: Extract
    private let delays: [Duration]
    private let maximumAttempts: Int
    private let logger = Logger(subsystem: "com.abigent.desktop", category: "result-recovery")
    private var recoveries: [RecoveryKey: Recovery] = [:]

    public init(
        delays: [Duration]? = nil,
        maximumAttempts: Int? = nil,
        extract: @escaping Extract
    ) {
        if let delays, !delays.isEmpty {
            self.delays = delays
            self.maximumAttempts = max(maximumAttempts ?? delays.count, delays.count)
        } else {
            self.delays = Self.defaultDelays
            self.maximumAttempts = max(maximumAttempts ?? 120, Self.defaultDelays.count)
        }
        self.extract = extract
    }

    public func recover(
        sessionID: String,
        stopObservedAt: Date,
        deliver: @escaping Deliver
    ) {
        let key = RecoveryKey(sessionID: sessionID, stopObservedAt: stopObservedAt)
        guard recoveries[key] == nil else { return }
        let generation = UUID()
        let delays = self.delays
        let maximumAttempts = self.maximumAttempts
        let extract = self.extract
        let task = Task { [weak self] in
            var lastError: Error?
            for attempt in 0..<maximumAttempts {
                guard !Task.isCancelled else { return }
                let delay = delays[min(attempt, delays.count - 1)]
                if delay > .zero {
                    do { try await Task.sleep(for: delay) }
                    catch { return }
                }
                guard !Task.isCancelled else { return }
                do {
                    let result = try await extract(sessionID, stopObservedAt)
                    guard !Task.isCancelled else { return }
                    await deliver(result)
                    await self?.finish(key: key, generation: generation)
                    return
                } catch {
                    lastError = error
                    if attempt == maximumAttempts - 1 {
                        await self?.recordFailure(
                            key: key,
                            generation: generation,
                            attempts: maximumAttempts,
                            error: lastError
                        )
                    }
                }
            }
        }
        recoveries[key] = Recovery(generation: generation, task: task)
    }

    public func cancelAll() {
        recoveries.values.forEach { $0.task.cancel() }
        recoveries.removeAll()
    }

    var activeRecoveryCount: Int { recoveries.count }

    private func finish(key: RecoveryKey, generation: UUID) {
        guard recoveries[key]?.generation == generation else { return }
        recoveries[key] = nil
    }

    private func recordFailure(
        key: RecoveryKey,
        generation: UUID,
        attempts: Int,
        error: Error?
    ) {
        guard recoveries[key]?.generation == generation else { return }
        let category = error.map { String(describing: type(of: $0)) } ?? "unknown"
        logger.error(
            "Final result recovery timed out; session=\(key.sessionID, privacy: .private) attempts=\(attempts) error=\(category, privacy: .public)"
        )
        recoveries[key] = nil
    }
}
