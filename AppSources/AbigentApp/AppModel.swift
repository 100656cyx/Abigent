import AbigentCodex
import AbigentCore
import AbigentHooks
import AbigentPersistence
import AbigentRuntime
import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum ActionState: Equatable { case idle, sending, failed(String) }

    @Published private(set) var tasks: [AgentTask] = [] {
        didSet {
            petController.state = PetAnimationState.aggregate(tasks)
            petController.task = showHoverResults ? PetHoverState.featuredTask(tasks) : nil
        }
    }
    @Published private(set) var connectionMessage = "正在连接 Codex…"
    @Published private(set) var hookConnectionMessage = "Hook 尚未启动"
    @Published var drafts: [GlobalTaskID: String] = [:]
    @Published var actions: [GlobalTaskID: ActionState] = [:]
    @Published var showPet = true { didSet { petController.setVisible(showPet) } }
    @Published var petAlwaysOnTop = true { didSet { petController.setAlwaysOnTop(petAlwaysOnTop) } }
    @Published private(set) var petScale: CGFloat = PetPlacement.defaultScale
    @Published var notificationsEnabled = true
    @Published var accessibilityFallbackEnabled = false
    @Published var showHoverResults = UserDefaults.standard.object(forKey: "showHoverResults") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(showHoverResults, forKey: "showHoverResults")
            petController.task = showHoverResults ? PetHoverState.featuredTask(tasks) : nil
        }
    }
    @Published private(set) var hookInstallationStatus: HookInstallationStatus = .notInstalled
    @Published private(set) var hookSetupError: String?

    private let coordinator: TaskCoordinator?
    private let hookServer: HookSocketServer?
    private let hookNormalizer: CodexHookNormalizer?
    private let resultExtractor: CodexResultExtractor?
    private let resultRecovery: CodexResultRecoveryCoordinator?
    private let hookInstaller: CodexHookInstaller?
    private let notifications = NotificationCoordinator()
    private let petController = PetWindowController()
    private let petPreferences = PetPreferenceStore()
    private var started = false
    private var appServerRecoveryRequests: [String: Date] = [:]

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

    init(
        coordinator: TaskCoordinator?,
        hookServer: HookSocketServer? = nil,
        hookNormalizer: CodexHookNormalizer? = nil,
        resultExtractor: CodexResultExtractor? = nil,
        hookInstaller: CodexHookInstaller? = nil
    ) {
        self.coordinator = coordinator
        self.hookServer = hookServer
        self.hookNormalizer = hookNormalizer
        self.resultExtractor = resultExtractor
        self.resultRecovery = resultExtractor.map { extractor in
            CodexResultRecoveryCoordinator { sessionID, stopObservedAt in
                try await extractor.extract(sessionID: sessionID, stopObservedAt: stopObservedAt)
            }
        }
        self.hookInstaller = hookInstaller
        petController.onOpenCodex = { [weak self] task in self?.openCodex(task) }
        petController.onPlacementChange = { [weak self] placement in
            guard let self else { return }
            self.petScale = placement.normalizedScale
            Task { try? await self.petPreferences.save(placement) }
        }
        petController.setVisible(true)
        hookInstallationStatus = hookInstaller?.inspect() ?? .notInstalled
        Task {
            let placement = await petPreferences.load()
            petScale = placement.normalizedScale
            petController.apply(placement)
            await start()
        }
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
            let sessionRoot = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".codex/sessions", isDirectory: true)
            let hookServer = HookSocketServer(
                socketURL: FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent(".abigent/run/bridge.sock")
            )
            let codexDirectory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".codex", isDirectory: true)
            let hookInstaller = CodexHookInstaller(
                configurationURL: codexDirectory.appendingPathComponent("hooks.json"),
                backupURL: codexDirectory.appendingPathComponent("hooks.abigent.backup.json"),
                receiptURL: support.appendingPathComponent("hook-installation.json")
            )
            return AppModel(
                coordinator: TaskCoordinator(
                    connector: CodexConnector(transport: transport, sessionRootURL: sessionRoot),
                    repository: repository
                ),
                hookServer: hookServer,
                hookNormalizer: CodexHookNormalizer(),
                resultExtractor: CodexResultExtractor(sessionsRoot: sessionRoot),
                hookInstaller: hookInstaller
            )
        } catch {
            return AppModel(coordinator: nil)
        }
    }

    var hooksInstalled: Bool {
        if case .installed = hookInstallationStatus { return true }
        return false
    }

    var petScalePercent: Int { Int((petScale * 100).rounded()) }

    func setPetScale(_ value: CGFloat, persist: Bool = true) {
        let normalized = min(max(value, PetPlacement.minimumScale), PetPlacement.maximumScale)
        petScale = normalized
        petController.setScale(normalized, persist: persist)
    }

    func resetPetScale() { setPetScale(PetPlacement.defaultScale) }

    func enableHooks() {
        guard let hookInstaller else { return }
        let relay = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/abigent-hook")
        guard FileManager.default.isExecutableFile(atPath: relay.path) else {
            hookSetupError = "安装包中缺少 Hook Relay，请重新安装最新版 Abigent。"
            return
        }
        do {
            try hookInstaller.install(relayURL: relay)
            hookInstallationStatus = hookInstaller.inspect()
            hookSetupError = nil
        } catch {
            hookSetupError = "无法安全更新 Codex Hook：\(String(describing: error))"
            hookInstallationStatus = hookInstaller.inspect()
        }
    }

    func disableHooks() {
        guard let hookInstaller else { return }
        do {
            try hookInstaller.uninstall()
            hookInstallationStatus = hookInstaller.inspect()
            hookSetupError = nil
        } catch {
            hookSetupError = "无法停用 Abigent Hook：\(String(describing: error))"
        }
    }

    func start() async {
        guard !started, let coordinator else {
            if coordinator == nil { connectionMessage = "无法创建本地任务数据库" }
            return
        }
        started = true
        startHookBridge(coordinator: coordinator)
        let updates = await coordinator.taskUpdates()
        let intents = await coordinator.notifications()
        Task { [weak self] in
            for await values in updates {
                await MainActor.run {
                    self?.tasks = values
                    self?.connectionMessage = "Codex 已连接"
                    self?.recoverMissingAppServerResults(in: values, coordinator: coordinator)
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

    private func startHookBridge(coordinator: TaskCoordinator) {
        guard let hookServer, let hookNormalizer else {
            hookConnectionMessage = "Hook 组件不可用"
            return
        }
        do {
            try hookServer.start()
            hookConnectionMessage = "Hook 正在监听"
        } catch {
            hookConnectionMessage = "Hook 启动失败，已使用日志恢复"
            return
        }
        let envelopes = hookServer.events()
        Task { [weak self] in
            for await envelope in envelopes {
                let events = await hookNormalizer.normalize(envelope)
                for event in events { try? await coordinator.ingest(event) }
                guard envelope.event == CodexHookEvent.stop.rawValue,
                      let sessionID = envelope.sessionID,
                      let recovery = self?.resultRecovery
                else { continue }
                await recovery.recover(
                    sessionID: sessionID,
                    stopObservedAt: envelope.observedAt
                ) { result in
                    let observed = ObservedAgentEvent(
                        event: .result(
                            id: .init(source: .codex, sourceTaskID: sessionID),
                            result: result
                        ),
                        provenance: .hook,
                        observedAt: envelope.observedAt
                    )
                    try? await coordinator.ingest(observed)
                }
            }
        }
    }

    private func recoverMissingAppServerResults(
        in values: [AgentTask],
        coordinator: TaskCoordinator
    ) {
        guard let resultRecovery else { return }
        for task in values where task.source == .codex {
            let sessionID = task.sourceTaskID
            guard [.completed, .failed, .cancelled].contains(task.state),
                  task.result == nil
            else {
                if task.result != nil || task.state == .working {
                    appServerRecoveryRequests[sessionID] = nil
                }
                continue
            }
            let completedAt = task.completedAt ?? task.updatedAt
            guard appServerRecoveryRequests[sessionID] != completedAt else { continue }
            appServerRecoveryRequests[sessionID] = completedAt
            Task {
                await resultRecovery.recover(
                    sessionID: sessionID,
                    stopObservedAt: completedAt
                ) { result in
                    let observed = ObservedAgentEvent(
                        event: .result(
                            id: .init(source: .codex, sourceTaskID: sessionID),
                            result: result
                        ),
                        provenance: .appServer,
                        observedAt: Date()
                    )
                    try? await coordinator.ingest(observed)
                }
            }
        }
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
