import AbigentCodex
import SwiftUI

struct HookSetupView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        GroupBox("Codex 实时同步") {
            VStack(alignment: .leading, spacing: 8) {
                Label(statusText, systemImage: model.hooksInstalled ? "checkmark.circle.fill" : "link.badge.plus")
                    .foregroundStyle(model.hooksInstalled ? .green : .primary)
                Text("启用后会向 ~/.codex/hooks.json 合并 7 个 Abigent 事件。Flux Island 和其他已有 Hook 会完整保留。所有事件只发送到本机 Abigent Socket。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("事件：SessionStart、UserPromptSubmit、PreToolUse、PermissionRequest、PostToolUse、Stop、SubagentStop")
                    .font(.caption2).foregroundStyle(.secondary)
                if let error = model.hookSetupError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                HStack {
                    if model.hooksInstalled {
                        Button("修复配置") { model.enableHooks() }
                        Button("停用 Abigent Hook", role: .destructive) { model.disableHooks() }
                    } else {
                        Button("启用实时同步") { model.enableHooks() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var statusText: String {
        switch model.hookInstallationStatus {
        case .notInstalled: "尚未启用 Hook 实时同步"
        case .installed: "Hook 实时同步已启用"
        case let .incomplete(events): "Hook 配置不完整（已发现 \(events.count) 项）"
        case .unreadable: "现有 Hook 配置无法读取，Abigent 不会覆盖"
        }
    }
}
