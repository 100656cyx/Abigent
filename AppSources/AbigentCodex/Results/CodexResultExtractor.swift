import AbigentCore
import Foundation

public enum CodexResultExtractorError: Error, Sendable, Equatable {
    case invalidSessionID
    case sessionNotFound
    case resultNotYetAvailable
}

public actor CodexResultExtractor {
    private let sessionsRoot: URL
    private let offsets: SessionOffsetStore

    public init(sessionsRoot: URL, offsets: SessionOffsetStore = .init()) {
        self.sessionsRoot = sessionsRoot
        self.offsets = offsets
    }

    public func extract(sessionID: String, stopObservedAt: Date) async throws -> TaskResult {
        guard UUID(uuidString: sessionID) != nil else { throw CodexResultExtractorError.invalidSessionID }
        guard let file = sessionFile(for: sessionID) else { throw CodexResultExtractorError.sessionNotFound }
        if let result = try parse(file: file, sessionID: sessionID, returnedAt: stopObservedAt) {
            return result
        }
        throw CodexResultExtractorError.resultNotYetAvailable
    }

    private func parse(file: URL, sessionID: String, returnedAt: Date) throws -> TaskResult? {
        let data = try Data(contentsOf: file)
        var starts: [(index: Int, timestamp: Date?)] = []
        var messages: [(Int, String)] = []
        var paths: [(Int, String)] = []
        let lines = data.split(separator: 0x0A)
        for (index, line) in lines.enumerated() {
            guard let root = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let payload = root["payload"] as? [String: Any]
            else { continue }
            if root["type"] as? String == "event_msg" {
                switch payload["type"] as? String {
                case "task_started":
                    starts.append((index, eventTimestamp(root["timestamp"])))
                case "agent_message":
                    if let message = payload["message"] as? String { messages.append((index, message)) }
                default: break
                }
            }
            if root["type"] as? String == "response_item",
               payload["type"] as? String == "fileChange",
               let path = payload["path"] as? String {
                paths.append((index, path))
            }
        }

        let turnStart: Int
        if starts.contains(where: { $0.timestamp != nil }) {
            guard let anchoredStart = starts.last(where: {
                guard let timestamp = $0.timestamp else { return false }
                return timestamp <= returnedAt
            }) else { return nil }
            turnStart = anchoredStart.index
        } else {
            turnStart = starts.last?.index ?? 0
        }
        let turnEnd = starts.first(where: { $0.index > turnStart }).map { $0.index - 1 } ?? Int.max
        guard let detail = messages.last(where: {
            $0.0 >= turnStart && $0.0 <= turnEnd
                && !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })?.1 else { return nil }
        let explicitPaths = orderedUnique(paths.filter {
            $0.0 >= turnStart && $0.0 <= turnEnd
        }.map(\.1))
        let summary = detail.split(separator: "\n", omittingEmptySubsequences: true).first.map {
            String($0.prefix(160))
        }
        Task { await offsets.commit(UInt64(data.count), for: sessionID) }
        return TaskResult(
            summary: summary,
            changedFiles: explicitPaths.isEmpty ? nil : explicitPaths,
            tests: nil,
            detail: detail,
            returnedAt: returnedAt
        )
    }

    private func eventTimestamp(_ value: Any?) -> Date? {
        guard let value = value as? String else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }

    private func sessionFile(for sessionID: String) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: sessionsRoot, includingPropertiesForKeys: nil)
        else { return nil }
        return enumerator.compactMap { $0 as? URL }.first {
            $0.pathExtension == "jsonl" && $0.deletingPathExtension().lastPathComponent.hasSuffix(sessionID)
        }
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
