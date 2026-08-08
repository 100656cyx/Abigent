import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        Form {
            Toggle("显示桌面宠物", isOn: $model.showPet)
            Toggle("宠物始终置顶", isOn: $model.petAlwaysOnTop)
            Toggle("关键节点通知", isOn: $model.notificationsEnabled)
            Toggle("悬停小猫显示任务结果", isOn: $model.showHoverResults)
            HookSetupView()
            Toggle("Codex 辅助功能降级", isOn: $model.accessibilityFallbackEnabled)
            Text("辅助功能仅用于桌面任务状态、定位和原地回复；默认关闭，不读取屏幕像素。")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24)
    }
}
