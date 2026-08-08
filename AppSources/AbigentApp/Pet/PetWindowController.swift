import AppKit
import SwiftUI

@MainActor
final class PetWindowController {
    var state: PetAnimationState = .idle { didSet { render() } }
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
        panel.contentView = NSHostingView(rootView: PetView(state: state))
    }

    private func positionOnVisibleScreen() {
        guard let frame = NSScreen.main?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: frame.maxX - panel.frame.width - 24, y: frame.minY + 24))
    }
}
