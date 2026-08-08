import AbigentCore
import AbigentHooks
import Darwin
import Foundation

@main
struct AbigentHookRelay {
    static func main() {
        guard let sourceValue = argument("--source"),
              let source = AgentKind(rawValue: sourceValue),
              let event = argument("--event")
        else { exit(0) }

        let input = FileHandle.standardInput.readDataToEndOfFile()
        guard input.count <= HookSocketServer.maximumMessageBytes,
              let payload = try? JSONDecoder().decode(JSONValue.self, from: input)
        else { exit(0) }
        let sessionID = sessionID(from: payload)
        let envelope = HookEnvelope(
            source: source,
            event: event,
            sessionID: sessionID,
            observedAt: Date(),
            payload: payload
        )
        guard var data = try? JSONEncoder().encode(envelope) else { exit(0) }
        data.append(0x0A)
        send(data, to: socketPath())
        exit(0)
    }

    private static func argument(_ name: String) -> String? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: name), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }

    private static func sessionID(from payload: JSONValue) -> String? {
        guard case let .object(object) = payload else { return nil }
        for key in ["session_id", "thread_id", "conversation_id"] {
            if case let .string(value)? = object[key] { return value }
        }
        return nil
    }

    private static func socketPath() -> String {
        if let override = ProcessInfo.processInfo.environment["ABIGENT_SOCKET_PATH"] { return override }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".abigent/run/bridge.sock").path
    }

    private static func send(_ data: Data, to path: String) {
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        defer { Darwin.close(fd) }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8) + [0]
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { return }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: pathBytes) }
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else { return }
        data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            _ = Darwin.write(fd, base, buffer.count)
        }
    }
}
