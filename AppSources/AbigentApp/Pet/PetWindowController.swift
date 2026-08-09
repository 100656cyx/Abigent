import AbigentCore
import AppKit
import SwiftUI

private final class SecondaryClickHostingView<Content: View>: NSHostingView<Content> {
    var onSecondaryClick: (() -> Void)?
    override func rightMouseDown(with event: NSEvent) { onSecondaryClick?() }
}

@MainActor
final class PetWindowController: NSObject, NSWindowDelegate {
    static let basePetSize = CGSize(width: 190, height: 250)

    var state: PetAnimationState = .idle { didSet { render() } }
    var task: AgentTask? { didSet { render() } }
    var onOpenCodex: ((AgentTask) -> Void)?
    var onToggleAlwaysOnTop: (() -> Void)?
    var onResetScale: (() -> Void)?
    var onPlacementChange: ((PetPlacement) -> Void)?
    private let panel: NSPanel
    private var scale: CGFloat = PetPlacement.defaultScale
    private var cardVisible = false
    private var controlsVisible = false
    private var alwaysOnTop = true
    private var applyingPlacement = false

    override init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 190, height: 250),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = .floating
        panel.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        positionOnVisibleScreen()
        render()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    func setVisible(_ visible: Bool) {
        if visible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        alwaysOnTop = enabled
        panel.level = enabled ? .floating : .normal
        render()
    }

    func setScale(_ value: CGFloat, persist: Bool = false) {
        scale = min(max(value, PetPlacement.minimumScale), PetPlacement.maximumScale)
        resizePanel(animated: false)
        render()
        if persist { publishPlacement() }
    }

    func apply(_ placement: PetPlacement) {
        applyingPlacement = true
        scale = placement.normalizedScale
        resizePanel(animated: false)
        var frame = panel.frame
        frame.origin = placement.origin
        panel.setFrame(clampedFrame(frame), display: true)
        applyingPlacement = false
        render()
    }

    var currentPlacement: PetPlacement {
        PetPlacement(scale: scale, origin: panel.frame.origin)
    }

    private func render() {
        let hosting = SecondaryClickHostingView(rootView: PetView(
            state: state,
            task: task,
            petScale: scale,
            alwaysOnTop: alwaysOnTop,
            controlsVisible: controlsVisible,
            onCardVisibilityChanged: { [weak self] visible in self?.setCardVisible(visible) },
            onControlVisibilityChanged: { [weak self] visible in
                self?.controlsVisible = visible
                self?.resizePanel(animated: true)
                self?.render()
            },
            onScaleChanged: { [weak self] scale in self?.setScale(scale) },
            onScaleEnded: { [weak self] in self?.publishPlacement() },
            onToggleAlwaysOnTop: { [weak self] in self?.onToggleAlwaysOnTop?() },
            onResetScale: { [weak self] in self?.onResetScale?() },
            onHide: { [weak self] in self?.setVisible(false) },
            onQuit: { NSApp.terminate(nil) },
            onOpenCodex: { [weak self] task in self?.onOpenCodex?(task) }
        ))
        hosting.onSecondaryClick = { [weak self] in
            guard let self else { return }
            self.controlsVisible.toggle()
            self.resizePanel(animated: true)
            self.render()
        }
        panel.contentView = hosting
    }

    private func setCardVisible(_ visible: Bool) {
        cardVisible = visible
        resizePanel(animated: true)
    }

    private func positionOnVisibleScreen() {
        guard let frame = NSScreen.main?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: frame.maxX - panel.frame.width - 24, y: frame.minY + 24))
    }

    private func resizePanel(animated: Bool) {
        let catWidth = Self.basePetSize.width * scale
        let targetWidth = max(catWidth, controlsVisible ? 230 : 0) + (cardVisible ? 380 : 0)
        let targetHeight = max(
            max(Self.basePetSize.height * scale, cardVisible ? 250 : 0),
            controlsVisible ? Self.basePetSize.height * scale + 245 : 0
        )
        var frame = panel.frame
        let rightEdge = frame.maxX
        frame.size = CGSize(width: targetWidth, height: targetHeight)
        frame.origin.x = rightEdge - targetWidth
        panel.setFrame(clampedFrame(frame), display: true, animate: animated)
    }

    private func clampedFrame(_ frame: CGRect) -> CGRect {
        guard let visibleFrame = (panel.screen ?? NSScreen.main)?.visibleFrame else { return frame }
        var next = frame
        next.size.width = min(next.width, visibleFrame.width)
        next.size.height = min(next.height, visibleFrame.height)
        next.origin.x = min(max(next.minX, visibleFrame.minX), visibleFrame.maxX - next.width)
        next.origin.y = min(max(next.minY, visibleFrame.minY), visibleFrame.maxY - next.height)
        return next
    }

    private func publishPlacement() {
        guard !applyingPlacement else { return }
        onPlacementChange?(currentPlacement)
    }

    func windowDidMove(_ notification: Notification) { publishPlacement() }

    @objc private func screenParametersChanged() {
        panel.setFrame(clampedFrame(panel.frame), display: true)
        publishPlacement()
    }
}
