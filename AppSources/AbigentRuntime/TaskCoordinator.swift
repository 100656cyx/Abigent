import AbigentCore
import AbigentPersistence
import Foundation

public struct NotificationIntent: Sendable, Equatable {
    public let task: AgentTask
    public let decision: NotificationDecision

    public init(task: AgentTask, decision: NotificationDecision) {
        self.task = task
        self.decision = decision
    }
}

public actor TaskCoordinator {
    private let connector: any AgentConnector
    private let repository: TaskRepository
    private var tasks: [GlobalTaskID: AgentTask] = [:]
    private var eventConsumer: Task<Void, Never>?
    private let taskStream: AsyncStream<[AgentTask]>
    private let taskContinuation: AsyncStream<[AgentTask]>.Continuation
    private let notificationStream: AsyncStream<NotificationIntent>
    private let notificationContinuation: AsyncStream<NotificationIntent>.Continuation

    public init(connector: any AgentConnector, repository: TaskRepository) {
        self.connector = connector
        self.repository = repository
        let taskPair = AsyncStream<[AgentTask]>.makeStream()
        taskStream = taskPair.stream
        taskContinuation = taskPair.continuation
        let notificationPair = AsyncStream<NotificationIntent>.makeStream()
        notificationStream = notificationPair.stream
        notificationContinuation = notificationPair.continuation
    }

    public func taskUpdates() -> AsyncStream<[AgentTask]> { taskStream }
    public func notifications() -> AsyncStream<NotificationIntent> { notificationStream }

    public func start() async throws {
        for task in try await repository.allTasks() { tasks[task.id] = task }
        publish()
        try await connector.connect()
        let snapshot = try await connector.initialSnapshot()
        let seen = Set(snapshot.map(\.id))
        for task in snapshot { try await store(task, previousState: tasks[task.id]?.state) }
        for (id, var task) in tasks where !seen.contains(id) && [.working, .needsInput].contains(task.state) {
            let previous = task.state
            task.state = .connectionUnknown
            task.updatedAt = Date()
            try await store(task, previousState: previous)
        }
        let events = await connector.events()
        eventConsumer = Task { [weak self] in
            for await event in events {
                do { try await self?.consume(event) }
                catch { await self?.markConnectionUnknown() }
            }
        }
    }

    public func stop() async {
        eventConsumer?.cancel()
        eventConsumer = nil
        await connector.disconnect()
    }

    public func respond(taskID: GlobalTaskID, requestID: String, response: UserResponse) async throws {
        try await connector.respond(taskID: sourceID(taskID), requestID: requestID, response: response)
    }

    public func cancel(taskID: GlobalTaskID) async throws {
        try await connector.cancel(taskID: sourceID(taskID))
    }

    public func continueTask(taskID: GlobalTaskID, prompt: String) async throws {
        try await connector.continueTask(taskID: sourceID(taskID), prompt: prompt)
    }

    public func sourceURL(taskID: GlobalTaskID) async -> URL? {
        await connector.sourceURL(taskID: sourceID(taskID))
    }

    private func consume(_ event: AgentEvent) async throws {
        switch event {
        case let .snapshot(task): try await store(task, previousState: tasks[task.id]?.state)
        case let .stateChanged(id, _, _), let .attention(id, _), let .result(id, _):
            guard let current = tasks[id] else { return }
            let next = try TaskReducer.reduce(current: current, event: event)
            try await store(next, previousState: current.state)
        case let .connectionChanged(state):
            if case .failed = state { await markConnectionUnknown() }
            if state == .disconnected { await markConnectionUnknown() }
        }
    }

    private func store(_ task: AgentTask, previousState: TaskState?) async throws {
        tasks[task.id] = task
        try await repository.upsert(task)
        if let previousState {
            let decision = NotificationPolicy.decision(previous: previousState, current: task)
            if decision != .none, try await repository.recordNotification(task: task) {
                notificationContinuation.yield(.init(task: task, decision: decision))
            }
        }
        publish()
    }

    private func markConnectionUnknown() async {
        for (id, var task) in tasks where [.working, .needsInput].contains(task.state) {
            task.state = .connectionUnknown
            task.updatedAt = Date()
            tasks[id] = task
            try? await repository.upsert(task)
        }
        publish()
    }

    private func publish() {
        taskContinuation.yield(tasks.values.sorted { $0.updatedAt > $1.updatedAt })
    }

    private func sourceID(_ id: GlobalTaskID) -> String {
        tasks[id]?.sourceTaskID ?? id.rawValue
    }
}
