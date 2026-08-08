import AbigentCodex
import AbigentCore
import CryptoKit
import Foundation

@main
struct AbigentDiagnostics {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first, ["doctor", "list", "watch"].contains(command) else {
            FileHandle.standardError.write(Data("Usage: abigent-diagnostics doctor|list|watch [--seconds N]\n".utf8))
            exit(64)
        }

        let transport = CodexProcessTransport(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["codex", "app-server", "--stdio"]
        )
        let connector = CodexConnector(transport: transport)
        do {
            try await connector.connect()
            switch command {
            case "doctor":
                emit(event: "doctor", state: "connected", detail: "app-server initialized")
            case "list":
                let tasks = try await connector.initialSnapshot()
                emit(event: "snapshot", state: "ok", detail: "taskCount=\(tasks.count)")
                for task in tasks {
                    emit(event: "task", taskID: task.sourceTaskID, state: task.state.rawValue, detail: nil)
                }
            case "watch":
                let seconds = secondsArgument(arguments) ?? 30
                let events = await connector.events()
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await event in events {
                            if Task.isCancelled { break }
                            emit(event: "agentEvent", state: summarizedState(event), detail: nil)
                        }
                    }
                    group.addTask {
                        try? await Task.sleep(for: .seconds(seconds))
                    }
                    _ = await group.next()
                    group.cancelAll()
                }
            default: break
            }
            await connector.disconnect()
        } catch {
            emit(event: "error", state: "failed", detail: String(describing: error))
            exit(1)
        }
    }

    private static func secondsArgument(_ arguments: [String]) -> Int? {
        guard let index = arguments.firstIndex(of: "--seconds"), arguments.indices.contains(index + 1) else { return nil }
        return Int(arguments[index + 1])
    }

    private static func summarizedState(_ event: AgentEvent) -> String {
        switch event {
        case let .snapshot(task): return task.state.rawValue
        case let .stateChanged(_, state, _): return state.rawValue
        case .attention: return TaskState.needsInput.rawValue
        case .result: return "result"
        case let .connectionChanged(state): return String(describing: state)
        }
    }

    private static func emit(event: String, taskID: String? = nil, state: String, detail: String?) {
        var object: [String: String] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "event": event,
            "state": state
        ]
        if let taskID {
            object["taskIDHash"] = SHA256.hash(data: Data(taskID.utf8)).map { String(format: "%02x", $0) }.joined()
        }
        if let detail { object["detail"] = detail }
        if let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
           let line = String(data: data, encoding: .utf8) {
            print(line)
        }
    }
}
