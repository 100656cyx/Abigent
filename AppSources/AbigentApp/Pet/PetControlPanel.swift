import AbigentCore
import SwiftUI

struct PetControlPanel: View {
    let scale: CGFloat
    let alwaysOnTop: Bool
    let hasResult: Bool
    let onShowResult: () -> Void
    let onToggleAlwaysOnTop: () -> Void
    let onResetScale: () -> Void
    let onOpenSettings: () -> Void
    let onHide: () -> Void
    let onQuit: () -> Void
    let onScaleChanged: (CGFloat) -> Void
    let onScaleEnded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("Abigent 小猫").font(.headline)
                Spacer()
                Circle().fill(.green).frame(width: 8, height: 8)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                action("doc.text", "结果", disabled: !hasResult, perform: onShowResult)
                action(alwaysOnTop ? "pin.fill" : "pin", "置顶", perform: onToggleAlwaysOnTop)
                action("arrow.counterclockwise", "复原", perform: onResetScale)
                action("gearshape", "设置", perform: onOpenSettings)
                action("eye.slash", "隐藏", perform: onHide)
                action("power", "退出", role: .destructive, perform: onQuit)
            }
            HStack {
                Text("小猫大小").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int((scale * 100).rounded()))%")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(get: { scale }, set: { onScaleChanged($0) }),
                in: PetPlacement.minimumScale...PetPlacement.maximumScale,
                onEditingChanged: { editing in if !editing { onScaleEnded() } }
            )
            .tint(Color(red: 0.66, green: 0.45, blue: 0.35))
        }
        .padding(13)
        .frame(width: 220)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.65)))
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
    }

    private func action(
        _ icon: String,
        _ label: String,
        disabled: Bool = false,
        role: ButtonRole? = nil,
        perform: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: perform) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(label).font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 45)
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? Color.red : Color.primary)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        .opacity(disabled ? 0.35 : 1)
        .disabled(disabled)
    }
}
