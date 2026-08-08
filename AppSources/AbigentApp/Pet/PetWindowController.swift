import AbigentCore
import AppKit
import SwiftUI

@MainActor
final class PetWindowController {
    var state: PetAnimationState = .idle { didSet { render() } }
    var task: AgentTask? { didSet { render() } }
    var onOpenCodex: ((AgentTask) -> Void)?
    private let panel: NSPanel

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 190, height: 250),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = .floating
        positionOnVisibleScreen()
        render()
    }

    func setVisible(_ visible: Bool) {
        if visible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        panel.level = enabled ? .floating : .normal
    }

    private func render() {
        panel.contentView = NSHostingView(rootView: PetView(
            state: state,
            task: task,
            onCardVisibilityChanged: { [weak self] visible in self?.setCardVisible(visible) },
            onOpenCodex: { [weak self] task in self?.onOpenCodex?(task) }
        ))
    }

    private func setCardVisible(_ visible: Bool) {
        let targetWidth: CGFloat = visible ? 570 : 190
        guard panel.frame.width != targetWidth else { return }
        var frame = panel.frame
        let rightEdge = frame.maxX
        frame.size.width = targetWidth
        frame.origin.x = rightEdge - targetWidth
        if let screen = panel.screen ?? NSScreen.main, frame.minX < screen.visibleFrame.minX {
            frame.origin.x = screen.visibleFrame.minX
        }
        panel.setFrame(frame, display: true, animate: true)
    }

    private func positionOnVisibleScreen() {
        guard let frame = NSScreen.main?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: frame.maxX - panel.frame.width - 24, y: frame.minY + 24))
    }
}
