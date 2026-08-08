import Foundation

public protocol AgentConnector: Sendable {
    var kind: AgentKind { get }

    func connect() async throws
    func disconnect() async
    func initialSnapshot() async throws -> [AgentTask]
    func events() async -> AsyncStream<AgentEvent>
    func respond(taskID: String, requestID: String, response: UserResponse) async throws
    func cancel(taskID: String) async throws
    func continueTask(taskID: String, prompt: String) async throws
    func sourceURL(taskID: String) async -> URL?
}
