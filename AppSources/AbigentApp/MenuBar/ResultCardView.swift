import AbigentCore
import SwiftUI

struct ResultCardView: View {
    @EnvironmentObject private var model: AppModel
    let task: AgentTask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.result?.summary ?? "Codex 未提供摘要").font(.caption)
            HStack {
                Label(task.result?.changedFiles.map { "\($0.count) 个文件" } ?? "文件信息未提供", systemImage: "doc")
                Label(testText, systemImage: "checkmark.circle")
            }.font(.caption2).foregroundStyle(.secondary)
            TextField("继续这个任务…", text: Binding(
                get: { model.drafts[task.id] ?? "" },
                set: { model.drafts[task.id] = $0 }
            )).textFieldStyle(.roundedBorder)
            HStack {
                Button("继续任务") { model.continueTask(task) }.disabled((model.drafts[task.id] ?? "").isEmpty)
                Button("打开 Codex") { model.openCodex(task) }
            }
        }
    }
    private var testText: String {
        guard let tests = task.result?.tests else { return "测试未运行/未提供" }
        return "\(tests.passed) 通过 · \(tests.failed) 失败"
    }
}
