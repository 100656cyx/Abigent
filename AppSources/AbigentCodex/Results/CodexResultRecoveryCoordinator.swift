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
    private let logger = Logger(subsystem: "com.abigent.desktop", category: "result-recovery")
    private var recoveries: [String: Recovery] = [:]

    public init(
        delays: [Duration]? = nil,
        extract: @escaping Extract
    ) {
        self.delays = delays ?? Self.defaultDelays
        self.extract = extract
    }

    public func recover(
        sessionID: String,
        stopObservedAt: Date,
        deliver: @escaping Deliver
    ) {
        recoveries[sessionID]?.task.cancel()
        let generation = UUID()
        let delays = self.delays
        let extract = self.extract
        let task = Task { [weak self] in
            var lastError: Error?
            for (index, delay) in delays.enumerated() {
                guard !Task.isCancelled else { return }
                if delay > .zero {
                    do { try await Task.sleep(for: delay) }
                    catch { return }
                }
                guard !Task.isCancelled else { return }
                do {
                    let result = try await extract(sessionID, stopObservedAt)
                    guard !Task.isCancelled else { return }
                    await deliver(result)
                    await self?.finish(sessionID: sessionID, generation: generation)
                    return
                } catch {
                    lastError = error
                    if index == delays.indices.last {
                        await self?.recordFailure(
                            sessionID: sessionID,
                            generation: generation,
                            attempts: delays.count,
                            error: lastError
                        )
                    }
                }
            }
        }
        recoveries[sessionID] = Recovery(generation: generation, task: task)
    }

    public func cancelAll() {
        recoveries.values.forEach { $0.task.cancel() }
        recoveries.removeAll()
    }

    var activeRecoveryCount: Int { recoveries.count }

    private func finish(sessionID: String, generation: UUID) {
        guard recoveries[sessionID]?.generation == generation else { return }
        recoveries[sessionID] = nil
    }

    private func recordFailure(
        sessionID: String,
        generation: UUID,
        attempts: Int,
        error: Error?
    ) {
        guard recoveries[sessionID]?.generation == generation else { return }
        let category = error.map { String(describing: type(of: $0)) } ?? "unknown"
        logger.error(
            "Final result recovery timed out; session=\(sessionID, privacy: .private) attempts=\(attempts) error=\(category, privacy: .public)"
        )
        recoveries[sessionID] = nil
    }
}
