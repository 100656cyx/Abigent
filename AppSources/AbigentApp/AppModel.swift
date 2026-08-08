import AbigentCodex
import AbigentCore
import AbigentPersistence
import AbigentRuntime
import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum ActionState: Equatable { case idle, sending, failed(String) }

    @Published private(set) var tasks: [AgentTask] = []
    @Published private(set) var connectionMessage = "正在连接 Codex…"
    @Published var drafts: [GlobalTaskID: String] = [:]
    @Published var actions: [GlobalTaskID: ActionState] = [:]
    @Published var showPet = true
    @Published var petAlwaysOnTop = true
    @Published var notificationsEnabled = true
    @Published var accessibilityFallbackEnabled = false

    private let coordinator: TaskCoordinator?
    private let notifications = NotificationCoordinator()
    private var started = false

    var attentionTasks: [AgentTask] { tasks.filter { $0.state == .needsInput } }
    var activeTasks: [AgentTask] { tasks.filter { [.working, .connectionUnknown].contains($0.state) } }
    var recentTasks: [AgentTask] {
        tasks.filter { [.completed, .failed, .cancelled].contains($0.state) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    var menuBarSymbol: String {
        if !attentionTasks.isEmpty { return "pawprint.fill" }
        if !activeTasks.isEmpty { return "pawprint" }
        return "cat.fill"
    }

    init(coordinator: TaskCoordinator?) {
        self.coordinator = coordinator
        Task { await start() }
    }

    static func make() -> AppModel {
        do {
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("Abigent", isDirectory: true)
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            let repository = try TaskRepository(databaseURL: support.appendingPathComponent("tasks.sqlite"))
            let transport = CodexProcessTransport(
                executableURL: URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex"),
                arguments: ["app-server", "--stdio"]
            )
            return AppModel(coordinator: TaskCoordinator(
                connector: CodexConnector(transport: transport),
                repository: repository
            ))
        } catch {
            return AppModel(coordinator: nil)
        }
    }

    func start() async {
        guard !started, let coordinator else {
            if coordinator == nil { connectionMessage = "无法创建本地任务数据库" }
            return
        }
        started = true
        let updates = await coordinator.taskUpdates()
        let intents = await coordinator.notifications()
        Task { [weak self] in
            for await values in updates {
                await MainActor.run {
                    self?.tasks = values
                    self?.connectionMessage = "Codex 已连接"
                }
            }
        }
        Task { [weak self] in
            for await intent in intents {
                guard let self, self.notificationsEnabled else { continue }
                await self.notifications.deliver(intent)
            }
        }
        do { try await coordinator.start() }
        catch { connectionMessage = "Codex 连接失败：\(String(describing: error))" }
    }

    func respond(to task: AgentTask, response: UserResponse) {
        guard let requestID = task.attentionRequest?.id, let coordinator else { return }
        actions[task.id] = .sending
        Task {
            do {
                try await coordinator.respond(taskID: task.id, requestID: requestID, response: response)
                drafts[task.id] = nil
                actions[task.id] = .idle
            } catch { actions[task.id] = .failed(String(describing: error)) }
        }
    }

    func continueTask(_ task: AgentTask) {
        guard let coordinator, let prompt = drafts[task.id], !prompt.isEmpty else { return }
        actions[task.id] = .sending
        Task {
            do {
                try await coordinator.continueTask(taskID: task.id, prompt: prompt)
                drafts[task.id] = nil
                actions[task.id] = .idle
            } catch { actions[task.id] = .failed(String(describing: error)) }
        }
    }

    func cancel(_ task: AgentTask) {
        guard let coordinator else { return }
        Task {
            do { try await coordinator.cancel(taskID: task.id) }
            catch { actions[task.id] = .failed(String(describing: error)) }
        }
    }

    func openCodex(_ task: AgentTask) {
        guard let coordinator else { return }
        Task {
            if let url = await coordinator.sourceURL(taskID: task.id) {
                NSWorkspace.shared.open(url)
            } else if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex").first {
                app.activate(options: [.activateAllWindows])
            } else {
                _ = try? await NSWorkspace.shared.openApplication(
                    at: URL(fileURLWithPath: "/Applications/ChatGPT.app"),
                    configuration: .init()
                )
            }
        }
    }
}
