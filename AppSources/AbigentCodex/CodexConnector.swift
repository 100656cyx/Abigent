import AbigentCore
import Foundation

public enum CodexConnectorError: Error, Sendable, Equatable {
    case notConnected
    case unknownAttentionRequest(String)
    case noActiveTurn(String)
    case unsupportedResponse
}

public actor CodexConnector: AgentConnector {
    private enum PendingKind: Sendable {
        case command
        case userInput(questionID: String)
    }

    private struct PendingRequest: Sendable {
        let rpcID: JSONRPCID
        let kind: PendingKind
    }

    public nonisolated let kind = AgentKind.codex
    private let transport: any CodexTransporting
    private let stream: AsyncStream<AgentEvent>
    private let continuation: AsyncStream<AgentEvent>.Continuation
    private var consumer: Task<Void, Never>?
    private var pendingRequests: [String: PendingRequest] = [:]
    private var activeTurns: [String: String] = [:]
    private var connected = false

    public init(transport: any CodexTransporting = CodexProcessTransport()) {
        self.transport = transport
        let pair = AsyncStream<AgentEvent>.makeStream()
        self.stream = pair.stream
        self.continuation = pair.continuation
    }

    public func connect() async throws {
        guard !connected else { return }
        continuation.yield(.connectionChanged(.connecting))
        try await transport.start()
        consumer = Task { [weak self, transport] in
            for await event in await transport.messages() {
                await self?.handle(event)
            }
        }
        _ = try await transport.send(
            method: "initialize",
            params: .object([
                "clientInfo": .object([
                    "name": .string("abigent"),
                    "title": .string("Abigent"),
                    "version": .string("0.1.0")
                ]),
                "capabilities": .object([:])
            ])
        )
        try await transport.notify(method: "initialized", params: .object([:]))
        connected = true
        continuation.yield(.connectionChanged(.connected))
    }

    public func disconnect() async {
        consumer?.cancel()
        consumer = nil
        await transport.stop()
        connected = false
        continuation.yield(.connectionChanged(.disconnected))
    }

    public func initialSnapshot() async throws -> [AgentTask] {
        guard connected else { throw CodexConnectorError.notConnected }
        var tasks: [AgentTask] = []
        var cursor: String?
        repeat {
            var params: [String: JSONValue] = ["limit": .number(100)]
            if let cursor { params["cursor"] = .string(cursor) }
            let result = try await transport.send(method: "thread/list", params: .object(params))
            let response = try result.decoded(as: CodexThreadListResponse.self)
            tasks.append(contentsOf: response.data.map(CodexMapper.task(from:)))
            cursor = response.nextCursor
        } while cursor != nil
        return tasks
    }

    public func events() async -> AsyncStream<AgentEvent> { stream }

    public func respond(taskID: String, requestID: String, response: UserResponse) async throws {
        guard let pending = pendingRequests.removeValue(forKey: requestID) else {
            throw CodexConnectorError.unknownAttentionRequest(requestID)
        }
        let result: JSONValue
        switch (pending.kind, response) {
        case (.command, let .choice(id)):
            result = .object(["decision": .string(id)])
        case let (.userInput(questionID), .choice(id)):
            result = userInputResult(questionID: questionID, values: [id])
        case let (.userInput(questionID), .text(text)):
            result = userInputResult(questionID: questionID, values: [text])
        default:
            pendingRequests[requestID] = pending
            throw CodexConnectorError.unsupportedResponse
        }
        try await transport.respond(id: pending.rpcID, result: result)
        continuation.yield(.stateChanged(
            id: .init(source: .codex, sourceTaskID: taskID),
            state: .working,
            updatedAt: Date()
        ))
    }

    public func cancel(taskID: String) async throws {
        guard let turnID = activeTurns[taskID] else { throw CodexConnectorError.noActiveTurn(taskID) }
        _ = try await transport.send(
            method: "turn/interrupt",
            params: .object(["threadId": .string(taskID), "turnId": .string(turnID)])
        )
    }

    public func continueTask(taskID: String, prompt: String) async throws {
        _ = try await transport.send(
            method: "turn/start",
            params: .object([
                "threadId": .string(taskID),
                "input": .array([.object(["type": .string("text"), "text": .string(prompt)])])
            ])
        )
    }

    public func sourceURL(taskID: String) async -> URL? { nil }

    private func handle(_ event: CodexTransportEvent) {
        switch event {
        case let .message(message): handle(message)
        case .protocolError: break
        case .diagnostic: break
        case let .exited(status):
            connected = false
            continuation.yield(.connectionChanged(.failed(message: "Codex app-server exited (\(status))")))
        }
    }

    private func handle(_ message: JSONRPCMessage) {
        guard let method = message.method, let params = message.params else { return }
        switch method {
        case "turn/started":
            guard let value = try? params.decoded(as: CodexTurnNotification.self) else { return }
            activeTurns[value.threadId] = value.turn.id
            continuation.yield(.stateChanged(
                id: taskID(value.threadId),
                state: .working,
                updatedAt: value.turn.startedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? Date()
            ))
        case "turn/completed":
            guard let value = try? params.decoded(as: CodexTurnNotification.self) else { return }
            activeTurns.removeValue(forKey: value.threadId)
            let state = CodexMapper.state(threadStatus: "idle", lastTurnStatus: value.turn.status)
            let date = value.turn.completedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? Date()
            continuation.yield(.stateChanged(id: taskID(value.threadId), state: state, updatedAt: date))
            if let result = CodexMapper.result(from: value.turn) {
                continuation.yield(.result(id: taskID(value.threadId), result: result))
            }
        case "item/commandExecution/requestApproval":
            guard let id = message.id,
                  let approval = try? params.decoded(as: CodexCommandApproval.self)
            else { return }
            let token = requestToken(id)
            pendingRequests[token] = .init(rpcID: id, kind: .command)
            continuation.yield(.attention(
                id: taskID(approval.threadId),
                request: CodexMapper.attention(from: approval, requestID: token)
            ))
        case "item/tool/requestUserInput":
            guard let id = message.id,
                  let request = try? params.decoded(as: CodexUserInputRequest.self),
                  let questionID = request.questions.first?.id
            else { return }
            let token = requestToken(id)
            pendingRequests[token] = .init(rpcID: id, kind: .userInput(questionID: questionID))
            continuation.yield(.attention(
                id: taskID(request.threadId),
                request: CodexMapper.attention(from: request, requestID: token)
            ))
        default: break
        }
    }

    private func taskID(_ sourceTaskID: String) -> GlobalTaskID {
        .init(source: .codex, sourceTaskID: sourceTaskID)
    }

    private func requestToken(_ id: JSONRPCID) -> String {
        switch id {
        case let .integer(value): return "i:\(value)"
        case let .string(value): return "s:\(value)"
        }
    }

    private func userInputResult(questionID: String, values: [String]) -> JSONValue {
        .object(["answers": .object([questionID: .object(["answers": .array(values.map(JSONValue.string))])])])
    }
}
