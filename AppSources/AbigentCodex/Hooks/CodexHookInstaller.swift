import Foundation

public struct CodexHookInstaller {
    public static let marker = "com.abigent.desktop"

    private let configurationURL: URL
    private let backupURL: URL
    private let receiptURL: URL
    private let fileManager: FileManager

    public init(
        configurationURL: URL,
        backupURL: URL,
        receiptURL: URL,
        fileManager: FileManager = .default
    ) {
        self.configurationURL = configurationURL
        self.backupURL = backupURL
        self.receiptURL = receiptURL
        self.fileManager = fileManager
    }

    public func inspect() -> HookInstallationStatus {
        guard fileManager.fileExists(atPath: configurationURL.path) else { return .notInstalled }
        do {
            let root = try readRoot()
            let owned = try ownedCommands(in: root)
            guard !owned.isEmpty else { return .notInstalled }
            let events = Set(owned.map(\.event))
            let paths = Set(owned.map(\.relayPath))
            if events == Set(CodexHookEvent.allCases.map(\.rawValue)), paths.count == 1,
               let path = paths.first {
                return .installed(events: events, relayPath: path)
            }
            return .incomplete(events: events)
        } catch {
            return .unreadable(String(describing: error))
        }
    }

    public func install(relayURL: URL, installedAt: Date = Date()) throws {
        var root = try readRootAllowingMissing()
        var hooks = try hooksObject(from: root)
        for event in CodexHookEvent.allCases {
            var groups = try groups(for: event.rawValue, in: hooks)
            groups = groups.compactMap(removingOwnedHooks)
            let ownedGroup = Self.group(event: event, relayURL: relayURL)
            guard let ownedEntries = ownedGroup["hooks"] as? [[String: Any]],
                  let ownedEntry = ownedEntries.first
            else { throw CodexHookInstallerError.validationFailed }
            if groups.isEmpty {
                groups.append(ownedGroup)
            } else {
                guard var entries = groups[0]["hooks"] as? [[String: Any]] else {
                    throw CodexHookInstallerError.malformedEvent(event.rawValue)
                }
                entries.append(ownedEntry)
                groups[0]["hooks"] = entries
            }
            hooks[event.rawValue] = groups
        }
        root["hooks"] = hooks
        try persist(root: root, createBackup: fileManager.fileExists(atPath: configurationURL.path))
        let receipt = HookInstallationReceipt(
            relayPath: relayURL.path,
            events: CodexHookEvent.allCases.map(\.rawValue),
            installedAt: installedAt
        )
        try fileManager.createDirectory(
            at: receiptURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(receipt).write(to: receiptURL, options: .atomic)
    }

    public func uninstall() throws {
        guard fileManager.fileExists(atPath: configurationURL.path) else {
            try? fileManager.removeItem(at: receiptURL)
            return
        }
        var root = try readRoot()
        var hooks = try hooksObject(from: root)
        for key in Array(hooks.keys) {
            var groups = try groups(for: key, in: hooks)
            groups = groups.compactMap(removingOwnedHooks)
            if groups.isEmpty { hooks.removeValue(forKey: key) }
            else { hooks[key] = groups }
        }
        if hooks.isEmpty { root.removeValue(forKey: "hooks") }
        else { root["hooks"] = hooks }
        try persist(root: root, createBackup: true)
        try? fileManager.removeItem(at: receiptURL)
    }

    private func readRootAllowingMissing() throws -> [String: Any] {
        guard fileManager.fileExists(atPath: configurationURL.path) else { return [:] }
        return try readRoot()
    }

    private func readRoot() throws -> [String: Any] {
        let value = try JSONSerialization.jsonObject(with: Data(contentsOf: configurationURL))
        guard let root = value as? [String: Any] else { throw CodexHookInstallerError.malformedRoot }
        return root
    }

    private func hooksObject(from root: [String: Any]) throws -> [String: Any] {
        guard let value = root["hooks"] else { return [:] }
        guard let hooks = value as? [String: Any] else { throw CodexHookInstallerError.malformedHooks }
        return hooks
    }

    private func groups(for event: String, in hooks: [String: Any]) throws -> [[String: Any]] {
        guard let value = hooks[event] else { return [] }
        guard let groups = value as? [[String: Any]] else {
            throw CodexHookInstallerError.malformedEvent(event)
        }
        return groups
    }

    private func removingOwnedHooks(_ group: [String: Any]) -> [String: Any]? {
        guard let hooks = group["hooks"] as? [[String: Any]] else { return group }
        let retained = hooks.filter { hook in
            guard let command = hook["command"] as? String else { return true }
            return !command.contains(Self.marker)
        }
        guard !retained.isEmpty else { return nil }
        var next = group
        next["hooks"] = retained
        return next
    }

    private func ownedCommands(in root: [String: Any]) throws -> [(event: String, relayPath: String)] {
        let hooks = try hooksObject(from: root)
        var result: [(String, String)] = []
        for (event, _) in hooks {
            for group in try groups(for: event, in: hooks) {
                guard let entries = group["hooks"] as? [[String: Any]] else { continue }
                for entry in entries {
                    guard let command = entry["command"] as? String,
                          command.contains(Self.marker),
                          let relayPath = Self.argument(named: "--relay", in: command)
                    else { continue }
                    result.append((event, relayPath))
                }
            }
        }
        return result
    }

    private func persist(root: [String: Any], createBackup: Bool) throws {
        guard JSONSerialization.isValidJSONObject(root) else {
            throw CodexHookInstallerError.validationFailed
        }
        try fileManager.createDirectory(
            at: configurationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if createBackup {
            try? fileManager.removeItem(at: backupURL)
            try fileManager.copyItem(at: configurationURL, to: backupURL)
        }
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        _ = try JSONSerialization.jsonObject(with: data)
        try data.write(to: configurationURL, options: .atomic)
    }

    private static func group(event: CodexHookEvent, relayURL: URL) -> [String: Any] {
        let relayPath = relayURL.path
        let command = [
            shellQuote(relayPath),
            "--marker", shellQuote(marker),
            "--source", "codex",
            "--event", shellQuote(event.rawValue),
            "--relay", shellQuote(relayPath)
        ].joined(separator: " ")
        return ["hooks": [["type": "command", "command": command, "timeout": 5]]]
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func argument(named name: String, in command: String) -> String? {
        guard let range = command.range(of: name + " '") else { return nil }
        let suffix = command[range.upperBound...]
        guard let end = suffix.firstIndex(of: "'") else { return nil }
        return String(suffix[..<end]).replacingOccurrences(of: "'\\''", with: "'")
    }
}
