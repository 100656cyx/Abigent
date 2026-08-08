import AbigentCore
import SwiftUI

struct TaskRowView: View {
    @EnvironmentObject private var model: AppModel
    let task: AgentTask
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { expanded.toggle() } label: {
                HStack {
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title).lineLimit(1).foregroundStyle(.primary)
                        Text("Codex · \(task.projectName ?? "本地任务")").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(statusText).font(.caption).foregroundStyle(statusColor)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption)
                }
            }.buttonStyle(.plain)
            if expanded {
                if task.state == .needsInput { AttentionCardView(task: task) }
                else if task.result != nil { ResultCardView(task: task) }
                else { TaskDetailView(task: task) }
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
    }

    private var statusText: String {
        switch task.state {
        case .discovered: "已发现"
        case .working: "运行中"
        case .needsInput: "需要操作"
        case .completed: "已完成"
        case .failed: "失败"
        case .cancelled: "已取消"
        case .connectionUnknown: "状态未知"
        }
    }
    private var statusColor: Color {
        switch task.state {
        case .needsInput: .orange
        case .completed: .green
        case .failed: .red
        case .working: .blue
        default: .secondary
        }
    }
}
