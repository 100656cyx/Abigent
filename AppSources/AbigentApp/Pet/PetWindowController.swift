import AbigentCore
import AppKit
import SwiftUI

private final class PetHostingView<Content: View>: NSHostingView<Content> {
    var onSecondaryClick: (() -> Void)?
    var petDragAreaSize = CGSize.zero

    override func rightMouseDown(with event: NSEvent) { onSecondaryClick?() }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let dragArea = CGRect(origin: .zero, size: petDragAreaSize)
        guard dragArea.contains(point) else {
            super.mouseDown(with: event)
            return
        }
        window?.performDrag(with: event)
    }
}

@MainActor
final class PetWindowController: NSObject, NSWindowDelegate {
    static let basePetSize = CGSize(width: 190, height: 250)
    private static let resultGap: CGFloat = 14
    private static let controlGap: CGFloat = 12

    var state: PetAnimationState = .idle { didSet { renderPet() } }
    var task: AgentTask? {
        didSet {
            if task == nil { hideResultPanel(force: true) }
            if resultVisible { renderResultPanel() }
            if controlVisible { renderControlPanel() }
        }
    }
    var onOpenCodex: ((AgentTask) -> Void)?
    var onToggleAlwaysOnTop: (() -> Void)?
    var onResetScale: (() -> Void)?
    var onPlacementChange: ((PetPlacement) -> Void)?

    private let panel: NSPanel
    private let resultPanel: NSPanel
    private let controlPanel: NSPanel
    private var scale: CGFloat = PetPlacement.defaultScale
    private var alwaysOnTop = true
    private var applyingPlacement = false
    private var petHovered = false
    private var resultHovered = false
    private var resultVisible = false
    private var resultExpanded = false
    private var controlVisible = false
    private var hoverTask: Task<Void, Never>?

    override init() {
        panel = Self.makePanel(size: Self.basePetSize)
        resultPanel = Self.makePanel(size: CGSize(width: 382, height: 280))
        controlPanel = Self.makePanel(size: CGSize(width: 250, height: 260))
        super.init()
        panel.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        positionOnVisibleScreen()
        renderPet()
    }

    deinit {
        hoverTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    func setVisible(_ visible: Bool) {
        if visible {
            panel.orderFrontRegardless()
        } else {
            hoverTask?.cancel()
            resultPanel.orderOut(nil)
            controlPanel.orderOut(nil)
            resultVisible = false
            controlVisible = false
            panel.orderOut(nil)
        }
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        alwaysOnTop = enabled
        let level: NSWindow.Level = enabled ? .floating : .normal
        panel.level = level
        resultPanel.level = level
        controlPanel.level = level
        if controlVisible { renderControlPanel() }
    }

    func setScale(_ value: CGFloat, persist: Bool = false) {
        scale = min(max(value, PetPlacement.minimumScale), PetPlacement.maximumScale)
        resizePetPanel()
        renderPet()
        if controlVisible { renderControlPanel() }
        anchorAuxiliaryPanels()
        if persist { publishPlacement() }
    }

    func apply(_ placement: PetPlacement) {
        applyingPlacement = true
        scale = placement.normalizedScale
        var frame = CGRect(origin: placement.origin, size: scaledPetSize)
        frame = clampedFrame(frame, to: NSScreen.main?.visibleFrame)
        panel.setFrame(frame, display: true)
        applyingPlacement = false
        renderPet()
        anchorAuxiliaryPanels()
    }

    var currentPlacement: PetPlacement {
        PetPlacement(scale: scale, origin: panel.frame.origin)
    }

    private static func makePanel(size: CGSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = .floating
        return panel
    }

    private var scaledPetSize: CGSize {
        CGSize(width: Self.basePetSize.width * scale, height: Self.basePetSize.height * scale)
    }

    private func renderPet() {
        let hosting = PetHostingView(rootView: PetView(
            state: state,
            petScale: scale,
            onHoverChanged: { [weak self] hovering in self?.setPetHovered(hovering) }
        ))
        hosting.onSecondaryClick = { [weak self] in self?.toggleControlPanel() }
        hosting.petDragAreaSize = scaledPetSize
        panel.contentView = hosting
    }

    private func renderResultPanel() {
        guard let task else {
            hideResultPanel(force: true)
            return
        }
        let hosting = NSHostingView(rootView: HoverablePetResultCard(
            task: task,
            expanded: resultExpanded,
            onToggleExpanded: { [weak self] in
                guard let self else { return }
                self.resultExpanded.toggle()
                self.renderResultPanel()
                if !self.resultExpanded && !self.petHovered && !self.resultHovered {
                    self.scheduleResultHide()
                }
            },
            onOpenCodex: { [weak self] in self?.onOpenCodex?(task) },
            onHoverChanged: { [weak self] hovering in self?.setResultHovered(hovering) }
        ))
        resultPanel.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        let fitting = hosting.fittingSize
        resultPanel.setContentSize(CGSize(
            width: max(382, fitting.width),
            height: max(250, fitting.height)
        ))
        anchorResultPanel()
    }

    private func renderControlPanel() {
        let hosting = NSHostingView(rootView: PetControlPanel(
            scale: scale,
            alwaysOnTop: alwaysOnTop,
            hasResult: task?.result != nil,
            onShowResult: { [weak self] in
                guard let self, self.task?.result != nil else { return }
                self.resultExpanded = true
                self.showResultPanel()
                self.hideControlPanel()
            },
            onToggleAlwaysOnTop: { [weak self] in self?.onToggleAlwaysOnTop?() },
            onResetScale: { [weak self] in self?.onResetScale?() },
            onOpenSettings: {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            },
            onHide: { [weak self] in self?.setVisible(false) },
            onQuit: { NSApp.terminate(nil) },
            onScaleChanged: { [weak self] value in self?.setScale(value) },
            onScaleEnded: { [weak self] in self?.publishPlacement() }
        ))
        controlPanel.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        let fitting = hosting.fittingSize
        controlPanel.setContentSize(CGSize(
            width: max(250, fitting.width),
            height: max(250, fitting.height)
        ))
        anchorControlPanel()
    }

    private func setPetHovered(_ hovering: Bool) {
        petHovered = hovering
        hoverTask?.cancel()
        if hovering {
            guard task != nil else { return }
            hoverTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled, let self, self.petHovered else { return }
                self.showResultPanel()
            }
        } else if !resultHovered && !resultExpanded {
            scheduleResultHide()
        }
    }

    private func setResultHovered(_ hovering: Bool) {
        resultHovered = hovering
        hoverTask?.cancel()
        if !hovering && !petHovered && !resultExpanded { scheduleResultHide() }
    }

    private func scheduleResultHide() {
        hoverTask?.cancel()
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let self,
                  !self.petHovered, !self.resultHovered, !self.resultExpanded
            else { return }
            self.hideResultPanel()
        }
    }

    private func showResultPanel() {
        guard task != nil else { return }
        resultVisible = true
        renderResultPanel()
        resultPanel.orderFrontRegardless()
    }

    private func hideResultPanel(force: Bool = false) {
        guard force || !resultExpanded else { return }
        resultVisible = false
        resultHovered = false
        if force { resultExpanded = false }
        resultPanel.orderOut(nil)
    }

    private func toggleControlPanel() {
        controlVisible.toggle()
        if controlVisible {
            renderControlPanel()
            controlPanel.orderFrontRegardless()
        } else {
            controlPanel.orderOut(nil)
        }
    }

    private func hideControlPanel() {
        controlVisible = false
        controlPanel.orderOut(nil)
    }

    private func positionOnVisibleScreen() {
        guard let frame = NSScreen.main?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(
            x: frame.maxX - panel.frame.width - 24,
            y: frame.minY + 24
        ))
    }

    private func resizePetPanel() {
        var frame = panel.frame
        let rightEdge = frame.maxX
        frame.size = scaledPetSize
        frame.origin.x = rightEdge - frame.width
        panel.setFrame(clampedFrame(frame, to: panel.screen?.visibleFrame), display: true)
    }

    private func anchorAuxiliaryPanels() {
        if resultVisible { anchorResultPanel() }
        if controlVisible { anchorControlPanel() }
    }

    private func anchorResultPanel() {
        guard let visibleFrame = (panel.screen ?? NSScreen.main)?.visibleFrame else { return }
        let petFrame = panel.frame
        var frame = resultPanel.frame
        let leftX = petFrame.minX - Self.resultGap - frame.width
        frame.origin.x = leftX >= visibleFrame.minX
            ? leftX
            : petFrame.maxX + Self.resultGap
        frame.origin.y = petFrame.minY
        resultPanel.setFrame(clampedFrame(frame, to: visibleFrame), display: true)
    }

    private func anchorControlPanel() {
        guard let visibleFrame = (panel.screen ?? NSScreen.main)?.visibleFrame else { return }
        let petFrame = panel.frame
        var frame = controlPanel.frame
        frame.origin.x = petFrame.maxX - frame.width
        let aboveY = petFrame.maxY + Self.controlGap
        frame.origin.y = aboveY + frame.height <= visibleFrame.maxY
            ? aboveY
            : petFrame.minY - Self.controlGap - frame.height
        controlPanel.setFrame(clampedFrame(frame, to: visibleFrame), display: true)
    }

    private func clampedFrame(_ frame: CGRect, to visibleFrame: CGRect?) -> CGRect {
        guard let visibleFrame else { return frame }
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

    func windowDidMove(_ notification: Notification) {
        publishPlacement()
        anchorAuxiliaryPanels()
    }

    @objc private func screenParametersChanged() {
        panel.setFrame(clampedFrame(panel.frame, to: panel.screen?.visibleFrame), display: true)
        publishPlacement()
        anchorAuxiliaryPanels()
    }
}
