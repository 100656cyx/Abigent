import AbigentCore
import AppKit
import SwiftUI

struct PetView: View {
    let state: PetAnimationState
    let task: AgentTask?
    let onCardVisibilityChanged: (Bool) -> Void
    let onOpenCodex: (AgentTask) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cardVisible = false
    @State private var expanded = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 14) {
                if cardVisible, let task {
                    PetResultCard(
                        task: task,
                        expanded: expanded,
                        onToggleExpanded: { expanded.toggle() },
                        onOpenCodex: { onOpenCodex(task) }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .trailing)))
                    .onHover(perform: scheduleVisibility)
                }
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: petImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale(phase))
                    .rotationEffect(rotation(phase))
                    .offset(y: verticalOffset(phase))
                    .animation(.easeInOut(duration: 0.35), value: state)
                    .accessibilityLabel("Abigent，\(stateLabel)")
                    badge.padding(18)
                }
                .frame(width: 190, height: 250)
                .contentShape(Rectangle())
                .onHover(perform: scheduleVisibility)
            }
            .padding(5)
            .animation(.easeInOut(duration: 0.18), value: cardVisible)
        }
    }

    private func scheduleVisibility(_ hovering: Bool) {
        hoverTask?.cancel()
        if hovering {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled, task != nil else { return }
                await MainActor.run {
                    cardVisible = true
                    onCardVisibilityChanged(true)
                }
            }
        } else if !expanded {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    cardVisible = false
                    onCardVisibilityChanged(false)
                }
            }
        }
    }

    @ViewBuilder private var badge: some View {
        switch state {
        case .needsInput:
            Image(systemName: "exclamationmark")
                .font(.headline).foregroundStyle(.white).frame(width: 30, height: 30)
                .background(.orange, in: Circle()).shadow(radius: 5)
        case .working:
            ProgressView().controlSize(.small).padding(7).background(.regularMaterial, in: Circle())
        case .completed:
            Image(systemName: "checkmark").foregroundStyle(.white).frame(width: 30, height: 30)
                .background(.green, in: Circle()).shadow(radius: 5)
        case .disconnected:
            Image(systemName: "bolt.slash").foregroundStyle(.white).frame(width: 30, height: 30)
                .background(.gray, in: Circle())
        case .idle: EmptyView()
        }
    }

    private var petImage: NSImage {
        let installedBundle = Bundle.main.resourceURL
            .map { $0.appendingPathComponent("Abigent_AbigentApp.bundle") }
            .flatMap(Bundle.init(url:))
        let resources = installedBundle ?? Bundle.module
        let url = resources.url(forResource: "abigent-base", withExtension: "png", subdirectory: "Pet")
            ?? resources.url(forResource: "abigent-base", withExtension: "png")
        guard let url,
              let image = NSImage(contentsOf: url) else { return NSImage() }
        return image
    }
    private func scale(_ phase: Double) -> CGFloat {
        guard !reduceMotion else { return 1 }
        switch state {
        case .idle: return 1 + 0.006 * sin(phase * 2)
        case .working: return 1 + 0.004 * sin(phase * 4)
        case .needsInput: return 1 + 0.02 * max(0, sin(phase * 5))
        case .completed: return 1.03
        case .disconnected: return 0.98
        }
    }
    private func rotation(_ phase: Double) -> Angle {
        guard !reduceMotion else { return .zero }
        if state == .needsInput { return .degrees(sin(phase * 5) * 1.8) }
        return .zero
    }
    private func verticalOffset(_ phase: Double) -> CGFloat {
        guard !reduceMotion, state == .completed else { return 0 }
        return -4 * abs(sin(phase * 3))
    }
    private var stateLabel: String {
        switch state {
        case .idle: "空闲"
        case .working: "Codex 正在工作"
        case .needsInput: "Codex 需要操作"
        case .completed: "任务已完成"
        case .disconnected: "Codex 连接已中断"
        }
    }
}
