import AbigentCore
import SwiftUI

struct AttentionCardView: View {
    @EnvironmentObject private var model: AppModel
    let task: AgentTask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.attentionRequest?.title ?? "Codex 需要输入").font(.subheadline.weight(.semibold))
            if let body = task.attentionRequest?.body { Text(body).font(.caption).textSelection(.enabled) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(task.attentionRequest?.choices ?? [], id: \.id) { choice in
                        Button(choice.label) { model.respond(to: task, response: .choice(id: choice.id)) }
                    }
                }
            }
            TextField("输入回复…", text: Binding(
                get: { model.drafts[task.id] ?? "" },
                set: { model.drafts[task.id] = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            HStack {
                Button("发送") { model.respond(to: task, response: .text(model.drafts[task.id] ?? "")) }
                    .disabled((model.drafts[task.id] ?? "").isEmpty)
                Button("打开 Codex") { model.openCodex(task) }
            }
        }
    }
}
