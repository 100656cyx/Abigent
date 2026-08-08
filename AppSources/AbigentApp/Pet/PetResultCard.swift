import AbigentCore
import SwiftUI

struct PetResultCard: View {
    let task: AgentTask
    let expanded: Bool
    let onToggleExpanded: () -> Void
    let onOpenCodex: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Codex", systemImage: "terminal")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(statusText).font(.caption).foregroundStyle(statusColor)
            }
            Text(task.title).font(.headline).lineLimit(2)
            if let project = task.projectName {
                Text(project).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            resultBody
            HStack(spacing: 12) {
                if task.result?.detail != nil {
                    Button(expanded ? "收起" : "查看完整结果", action: onToggleExpanded)
                        .buttonStyle(.link)
                }
                Spacer()
                Button("打开 Codex", action: onOpenCodex).buttonStyle(.link)
            }
        }
        .padding(16)
        .frame(width: 350, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.24)))
        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
    }

    @ViewBuilder private var resultBody: some View {
        if let text = expanded ? task.result?.detail : (task.result?.summary ?? task.result?.detail) {
            if expanded {
                ScrollView { Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 280)
            } else {
                Text(text).font(.callout).lineLimit(5)
            }
        } else if task.state == .completed {
            Text("任务已完成，结果同步中…").font(.callout).foregroundStyle(.secondary)
        } else if task.state == .working {
            Text("Codex 正在处理本次任务…").font(.callout).foregroundStyle(.secondary)
        } else if task.state == .needsInput {
            Text(task.attentionRequest?.body ?? "Codex 正在等待你的操作")
                .font(.callout).lineLimit(5)
        } else {
            Text("暂时没有可展示的结果").font(.callout).foregroundStyle(.secondary)
        }
        if let returnedAt = task.result?.returnedAt ?? task.completedAt {
            Text("返回时间：\(returnedAt.formatted(date: .omitted, time: .standard))")
                .font(.caption).foregroundStyle(.secondary)
        }
        if let files = task.result?.changedFiles, !files.isEmpty {
            Label("修改 \(files.count) 个文件", systemImage: "doc.badge.ellipsis")
                .font(.caption).foregroundStyle(.secondary)
        }
        if let tests = task.result?.tests {
            Label("测试 \(tests.passed) 通过 · \(tests.failed) 失败", systemImage: "checkmark.seal")
                .font(.caption).foregroundStyle(tests.failed == 0 ? .green : .red)
        }
    }

    private var statusText: String {
        switch task.state {
        case .discovered: "已发现"
        case .working: "工作中"
        case .needsInput: "需要操作"
        case .completed: "已完成"
        case .failed: "失败"
        case .cancelled: "已取消"
        case .connectionUnknown: "连接异常"
        }
    }
    private var statusColor: Color {
        switch task.state {
        case .needsInput: .orange
        case .working: .blue
        case .completed: .green
        case .failed: .red
        default: .secondary
        }
    }
}
