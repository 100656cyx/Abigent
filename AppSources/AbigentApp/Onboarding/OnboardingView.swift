import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: symbol)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 78, height: 78)
                .background(color.opacity(0.12), in: Circle())
            VStack(spacing: 8) {
                Text(title).font(.title2.bold())
                Text(message).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: 390)
            }
            if case .waitingForSessionStart = model.onboardingState {
                ProgressView().controlSize(.small)
            }
            HStack(spacing: 10) {
                if showsLaterButton { Button("稍后设置") { model.dismissOnboarding() } }
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.borderedProminent).disabled(primaryDisabled)
            }
            if case .ready = model.onboardingState {
                VStack(spacing: 5) {
                    Text("接下来试一试").font(.headline)
                    Text("在 Codex 发送一个任务，观察小猫开始工作；完成后悬停查看本轮摘要。")
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding(.top, 4)
            }
        }
        .padding(34).frame(width: 520, height: 390)
    }

    private var symbol: String {
        switch model.onboardingState {
        case .detecting, .waitingForSessionStart: "wave.3.right"
        case .codexMissing, .failed: "exclamationmark.triangle"
        case .hookNotInstalled: "link.badge.plus"
        case .restartRequired: "arrow.clockwise"
        case .ready: "checkmark.circle.fill"
        }
    }
    private var color: Color {
        switch model.onboardingState {
        case .codexMissing, .failed: .orange
        case .ready: .green
        default: Color(red: 0.66, green: 0.45, blue: 0.35)
        }
    }
    private var title: String {
        switch model.onboardingState {
        case .detecting: "正在检查 Codex"
        case .codexMissing: "没有找到 Codex"
        case .hookNotInstalled: "连接 Codex 实时状态"
        case .restartRequired: "请重新启动 Codex"
        case .waitingForSessionStart: "正在等待 Codex"
        case .ready: "Abigent 已连接"
        case .failed: "设置没有完成"
        }
    }
    private var message: String {
        switch model.onboardingState {
        case .detecting: "Abigent 正在本机检查 Codex 和实时同步设置。"
        case .codexMissing: "请先安装 Codex 桌面应用，再回到 Abigent 继续设置。"
        case .hookNotInstalled: "启用后，Abigent 会把自己的事件监听安全合并到 Codex 配置。已有 Flux Island 和其他 Hook 会保持不变。"
        case .restartRequired: "同步配置已经写好。请使用 ⌘Q 完全退出 Codex，再重新打开；只关闭窗口不会生效。"
        case .waitingForSessionStart: "Codex 已重新打开。请进入任意会话，Abigent 收到第一个真实事件后会自动完成连接。"
        case .ready: "实时任务状态和本轮回复摘要都将在这台 Mac 本地处理。"
        case let .failed(message): message
        }
    }
    private var primaryTitle: String {
        switch model.onboardingState {
        case .codexMissing: "重新检查"
        case .hookNotInstalled, .failed: "启用实时同步"
        case .restartRequired: "我已重新打开 Codex"
        case .ready: "开始使用"
        default: "正在等待"
        }
    }
    private var primaryDisabled: Bool {
        switch model.onboardingState {
        case .detecting, .waitingForSessionStart: true
        default: false
        }
    }
    private var showsLaterButton: Bool {
        switch model.onboardingState {
        case .hookNotInstalled, .codexMissing, .failed: true
        default: false
        }
    }
    private func primaryAction() {
        switch model.onboardingState {
        case .codexMissing: model.refreshOnboardingState()
        case .hookNotInstalled, .failed: model.enableHooks()
        case .restartRequired: model.waitForCodexSessionStart()
        case .ready: model.completeOnboarding()
        default: break
        }
    }
}
