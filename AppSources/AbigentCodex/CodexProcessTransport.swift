import Foundation

public enum CodexTransportError: Error, Sendable, Equatable {
    case alreadyRunning
    case notRunning
    case processLaunch(String)
    case processExited(Int32)
    case malformedMessage
    case remote(code: Int, message: String)
}

public enum CodexTransportEvent: Sendable, Equatable {
    case message(JSONRPCMessage)
    case protocolError
    case diagnostic(String)
    case exited(Int32)
}

public actor CodexProcessTransport {
    private let executableURL: URL
    private let arguments: [String]
    private let processFactory: @Sendable () -> Process
    private var process: Process?
    private var input: FileHandle?
    private var readTask: Task<Void, Never>?
    private var nextRequestID = 1
    private var pending: [JSONRPCID: CheckedContinuation<JSONValue, Error>] = [:]
    private let stream: AsyncStream<CodexTransportEvent>
    private let continuation: AsyncStream<CodexTransportEvent>.Continuation

    public init(
        executableURL: URL = URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [String] = ["codex", "app-server", "proxy"],
        processFactory: @escaping @Sendable () -> Process = { Process() }
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.processFactory = processFactory
        let pair = AsyncStream<CodexTransportEvent>.makeStream()
        self.stream = pair.stream
        self.continuation = pair.continuation
    }

    public func messages() -> AsyncStream<CodexTransportEvent> { stream }

    public func start() throws {
        guard process == nil else { throw CodexTransportError.alreadyRunning }
        let child = processFactory()
        let standardInput = Pipe()
        let standardOutput = Pipe()
        let standardError = Pipe()
        child.executableURL = executableURL
        child.arguments = arguments
        child.standardInput = standardInput
        child.standardOutput = standardOutput
        child.standardError = standardError
        child.terminationHandler = { [weak self] process in
            Task { await self?.processDidExit(process.terminationStatus) }
        }
        do { try child.run() }
        catch { throw CodexTransportError.processLaunch(String(describing: error)) }
        process = child
        input = standardInput.fileHandleForWriting
        readTask = Task { [weak self] in
            do {
                for try await line in standardOutput.fileHandleForReading.bytes.lines {
                    await self?.receive(line: line)
                }
            } catch {
                await self?.emitDiagnostic("stdout-read-failed")
            }
        }
        standardError.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { await self?.emitDiagnostic("codex-stderr") }
        }
    }

    public func send(method: String, params: JSONValue = .object([:])) async throws -> JSONValue {
        guard let input else { throw CodexTransportError.notRunning }
        let id = JSONRPCID.integer(nextRequestID)
        nextRequestID += 1
        let request = JSONRPCRequest(id: id, method: method, params: params)
        let data = try Self.lineData(request)
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            do { try input.write(contentsOf: data) }
            catch {
                pending.removeValue(forKey: id)
                continuation.resume(throwing: error)
            }
        }
    }

    public func notify(method: String, params: JSONValue = .object([:])) throws {
        guard let input else { throw CodexTransportError.notRunning }
        try input.write(contentsOf: Self.lineData(JSONRPCNotification(method: method, params: params)))
    }

    public func stop() {
        readTask?.cancel()
        readTask = nil
        input?.closeFile()
        input = nil
        if let process, process.isRunning { process.terminate() }
        process = nil
        failPending(with: CodexTransportError.processExited(0))
    }

    private func receive(line: String) {
        guard let data = line.data(using: .utf8),
              let message = try? JSONDecoder().decode(JSONRPCMessage.self, from: data)
        else {
            continuation.yield(.protocolError)
            return
        }
        if let id = message.id, let request = pending.removeValue(forKey: id) {
            if let error = message.error {
                request.resume(throwing: CodexTransportError.remote(code: error.code, message: error.message))
            } else {
                request.resume(returning: message.result ?? .null)
            }
        } else {
            continuation.yield(.message(message))
        }
    }

    private func processDidExit(_ status: Int32) {
        process = nil
        input = nil
        failPending(with: CodexTransportError.processExited(status))
        continuation.yield(.exited(status))
    }

    private func failPending(with error: Error) {
        let requests = pending.values
        pending.removeAll()
        for request in requests { request.resume(throwing: error) }
    }

    private func emitDiagnostic(_ message: String) {
        continuation.yield(.diagnostic(message))
    }

    private static func lineData<T: Encodable>(_ value: T) throws -> Data {
        var data = try JSONEncoder().encode(value)
        data.append(0x0A)
        return data
    }
}
