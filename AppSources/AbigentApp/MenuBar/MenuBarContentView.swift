import AbigentCore
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    section("需要操作", tasks: model.attentionTasks)
                    section("运行中", tasks: model.activeTasks)
                    section("最近完成", tasks: Array(model.recentTasks.prefix(10)))
                    if model.tasks.isEmpty {
                        ContentUnavailableView("暂无 Codex 任务", systemImage: "pawprint", description: Text("Abigent 会自动发现本机任务"))
                            .padding(.top, 70)
                    }
                }
                .padding(14)
            }
        }
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Abigent").font(.headline)
                Text(model.connectionMessage).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            SettingsLink { Image(systemName: "gearshape") }.buttonStyle(.plain)
        }
        .padding(14)
    }

    @ViewBuilder
    private func section(_ title: String, tasks: [AgentTask]) -> some View {
        if !tasks.isEmpty {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(tasks) { task in
                TaskRowView(task: task)
            }
        }
    }
}
