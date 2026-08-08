import AbigentCore
import Foundation

/// Observes Codex's local append-only session log. The desktop app owns a
/// private app-server connection, so a second app-server cannot receive its
/// live turn notifications. Session logs are the local, non-UI source of truth.
final class CodexSessionWatcher: @unchecked Sendable {
    private let rootURL: URL
    private var task: Task<Void, Never>?

    init(rootURL: URL) { self.rootURL = rootURL }

    func start(yield: @escaping @Sendable (AgentEvent) -> Void) {
        guard task == nil else { return }
        task = Task.detached(priority: .utility) { [rootURL] in
            var offsets: [URL: UInt64] = [:]
            var remainders: [URL: Data] = [:]
            while !Task.isCancelled {
                let files = Self.sessionFiles(below: rootURL)
                for file in files {
                    let size = Self.fileSize(file)
                    if offsets[file] == nil {
                        let data = (try? Data(contentsOf: file)) ?? Data()
                        offsets[file] = UInt64(data.count)
                        if let event = Self.initialLifecycleEvent(in: data, file: file) { yield(event) }
                        continue
                    }
                    guard let offset = offsets[file], size > offset,
                          let handle = try? FileHandle(forReadingFrom: file)
                    else { continue }
                    do {
                        try handle.seek(toOffset: offset)
                        let newData = try handle.readToEnd() ?? Data()
                        offsets[file] = offset + UInt64(newData.count)
                        var combined = remainders[file] ?? Data()
                        combined.append(newData)
                        let parts = combined.split(separator: 0x0A, omittingEmptySubsequences: false)
                        remainders[file] = parts.last.map { Data($0) } ?? Data()
                        for line in parts.dropLast() {
                            if let event = Self.event(from: Data(line), file: file) { yield(event) }
                        }
                    } catch { offsets[file] = size }
                    try? handle.close()
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private static func initialLifecycleEvent(in data: Data, file: URL) -> AgentEvent? {
        var latest: AgentEvent?
        for line in data.split(separator: 0x0A) {
            guard let event = event(from: Data(line), file: file) else { continue }
            if case let .stateChanged(_, state, _) = event {
                latest = state == .working || state == .needsInput ? event : nil
            }
        }
        guard let latest else { return nil }
        let modifiedAt = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            ?? .distantPast
        guard let sourceTaskID = taskID(from: file) else { return nil }
        if Date().timeIntervalSince(modifiedAt) <= 10 * 60 {
            let state: TaskState
            switch latest {
            case let .stateChanged(_, value, _): state = value
            default: return nil
            }
            return .stateChanged(
                id: .init(source: .codex, sourceTaskID: sourceTaskID),
                state: state,
                updatedAt: Date()
            )
        }
        return .stateChanged(
            id: .init(source: .codex, sourceTaskID: sourceTaskID),
            state: .discovered,
            updatedAt: Date()
        )
    }

    private static func event(from data: Data, file: URL) -> AgentEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = object["payload"] as? [String: Any],
              let sourceTaskID = taskID(from: file)
        else { return nil }
        let timestamp = (object["timestamp"] as? String).flatMap(parseDate) ?? Date()
        let id = GlobalTaskID(source: .codex, sourceTaskID: sourceTaskID)
        if object["type"] as? String == "event_msg" {
            switch payload["type"] as? String {
            case "task_started": return .stateChanged(id: id, state: .working, updatedAt: timestamp)
            case "task_complete": return .stateChanged(id: id, state: .completed, updatedAt: timestamp)
            default: return nil
            }
        }
        if object["type"] as? String == "response_item",
           payload["type"] as? String == "custom_tool_call",
           let name = payload["name"] as? String,
           name.localizedCaseInsensitiveContains("request_user_input") {
            return .stateChanged(id: id, state: .needsInput, updatedAt: timestamp)
        }
        return nil
    }

    private static func sessionFiles(below root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return enumerator.compactMap { value in
            guard let url = value as? URL, url.pathExtension == "jsonl" else { return nil }
            return url
        }
    }

    private static func fileSize(_ url: URL) -> UInt64 {
        ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?.uint64Value ?? 0
    }

    private static func taskID(from file: URL) -> String? {
        let stem = file.deletingPathExtension().lastPathComponent
        guard stem.count >= 36 else { return nil }
        let candidate = String(stem.suffix(36))
        return UUID(uuidString: candidate) == nil ? nil : candidate.lowercased()
    }

    private static func parseDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}
