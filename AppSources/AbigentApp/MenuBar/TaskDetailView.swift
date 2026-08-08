import AbigentCore
import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject private var model: AppModel
    let task: AgentTask

    var body: some View {
        HStack {
            Button("打开 Codex") { model.openCodex(task) }
            if task.state == .working { Button("取消任务", role: .destructive) { model.cancel(task) } }
        }
    }
}
