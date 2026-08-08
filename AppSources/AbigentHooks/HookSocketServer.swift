import Darwin
import Foundation

public final class HookSocketServer: @unchecked Sendable {
    public static let maximumMessageBytes = 1_048_576

    private let socketURL: URL
    private let stream: AsyncStream<HookEnvelope>
    private let continuation: AsyncStream<HookEnvelope>.Continuation
    private let lock = NSLock()
    private var descriptor: Int32 = -1
    private var acceptTask: Task<Void, Never>?

    public init(socketURL: URL) {
        self.socketURL = socketURL
        let pair = AsyncStream<HookEnvelope>.makeStream()
        stream = pair.stream
        continuation = pair.continuation
    }

    public func events() -> AsyncStream<HookEnvelope> { stream }

    public func start() throws {
        lock.lock()
        defer { lock.unlock() }
        guard descriptor < 0 else { return }
        try FileManager.default.createDirectory(
            at: socketURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? FileManager.default.removeItem(at: socketURL)

        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw HookSocketError.createFailed(errno) }
        do {
            try Self.bind(fd: fd, path: socketURL.path)
            guard Darwin.chmod(socketURL.path, 0o600) == 0 else {
                throw HookSocketError.permissionFailed
            }
            guard Darwin.listen(fd, 16) == 0 else { throw HookSocketError.listenFailed(errno) }
        } catch {
            Darwin.close(fd)
            try? FileManager.default.removeItem(at: socketURL)
            throw error
        }
        descriptor = fd
        let continuation = continuation
        acceptTask = Task.detached(priority: .utility) {
            Self.acceptLoop(serverFD: fd, continuation: continuation)
        }
    }

    public func stop() {
        lock.lock()
        let fd = descriptor
        descriptor = -1
        let task = acceptTask
        acceptTask = nil
        lock.unlock()
        task?.cancel()
        if fd >= 0 {
            Darwin.shutdown(fd, SHUT_RDWR)
            Darwin.close(fd)
        }
        try? FileManager.default.removeItem(at: socketURL)
    }

    deinit { stop() }

    private static func acceptLoop(
        serverFD: Int32,
        continuation: AsyncStream<HookEnvelope>.Continuation
    ) {
        while !Task.isCancelled {
            let client = Darwin.accept(serverFD, nil, nil)
            guard client >= 0 else {
                if errno == EINTR { continue }
                return
            }
            var peerUID: uid_t = 0
            var peerGID: gid_t = 0
            guard getpeereid(client, &peerUID, &peerGID) == 0, peerUID == geteuid() else {
                Darwin.close(client)
                continue
            }
            readClient(client, continuation: continuation)
            Darwin.close(client)
        }
    }

    private static func readClient(
        _ fd: Int32,
        continuation: AsyncStream<HookEnvelope>.Continuation
    ) {
        var data = Data()
        var bytes = [UInt8](repeating: 0, count: 8192)
        while data.count <= maximumMessageBytes {
            let count = Darwin.read(fd, &bytes, bytes.count)
            if count <= 0 { break }
            data.append(bytes, count: count)
            while let newline = data.firstIndex(of: 0x0A) {
                let line = data[..<newline]
                data.removeSubrange(...newline)
                guard line.count <= maximumMessageBytes,
                      let envelope = try? JSONDecoder().decode(HookEnvelope.self, from: Data(line)),
                      envelope.schemaVersion == 1
                else { continue }
                continuation.yield(envelope)
            }
        }
    }

    private static func bind(fd: Int32, path: String) throws {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8) + [0]
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard bytes.count <= capacity else { throw HookSocketError.pathTooLong }
        withUnsafeMutableBytes(of: &address.sun_path) { destination in
            destination.copyBytes(from: bytes)
        }
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else { throw HookSocketError.bindFailed(errno) }
    }
}
