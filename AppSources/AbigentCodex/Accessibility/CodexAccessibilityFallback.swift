import AppKit
@preconcurrency import ApplicationServices
import Foundation

public enum AccessibilityFallbackError: Error, Sendable, Equatable {
    case disabled
    case permissionDenied
    case codexNotRunning
    case taskNotFound
    case controlNotFound
    case actionFailed(String)
}

public enum CodexVisibleState: Sendable, Equatable {
    case working
    case needsInput
    case completed
    case unknown
}

public final class CodexAccessibilityFallback: @unchecked Sendable {
    private let authorizer: any AccessibilityAuthorizing
    private let enabled: @Sendable () -> Bool

    public init(
        authorizer: any AccessibilityAuthorizing = SystemAccessibilityAuthorizer(),
        enabled: @escaping @Sendable () -> Bool
    ) {
        self.authorizer = authorizer
        self.enabled = enabled
    }

    public func requestPermission() -> Bool {
        guard enabled() else { return false }
        return authorizer.isTrusted(promptIfNeeded: true)
    }

    public func visibleState(taskTitle: String) throws -> CodexVisibleState {
        let root = try trustedRoot()
        guard let task = root.firstDescendant(containingText: taskTitle) else {
            throw AccessibilityFallbackError.taskNotFound
        }
        let context = task.nearestContainer ?? task
        let text = context.flattenedText.lowercased()
        if containsAny(text, ["needs input", "需要操作", "allow", "允许", "deny", "拒绝"]) {
            return .needsInput
        }
        if containsAny(text, ["working", "running", "正在处理", "运行中", "thinking", "思考中"]) {
            return .working
        }
        if containsAny(text, ["completed", "done", "已完成", "finished"]) {
            return .completed
        }
        return .unknown
    }

    public func focusTask(taskTitle: String) throws {
        let root = try trustedRoot()
        guard let element = root.firstDescendant(containingText: taskTitle) else {
            throw AccessibilityFallbackError.taskNotFound
        }
        guard AXUIElementPerformAction(element.raw, kAXPressAction as CFString) == .success else {
            throw AccessibilityFallbackError.actionFailed("focus-task")
        }
    }

    public func submitChoice(label: String, taskTitle: String) throws {
        let root = try focusedTaskRoot(taskTitle: taskTitle)
        guard let button = root.firstDescendant(role: kAXButtonRole as String, exactText: label) else {
            throw AccessibilityFallbackError.controlNotFound
        }
        guard AXUIElementPerformAction(button.raw, kAXPressAction as CFString) == .success else {
            throw AccessibilityFallbackError.actionFailed("press-choice")
        }
    }

    public func submitText(_ text: String, taskTitle: String) throws {
        let root = try focusedTaskRoot(taskTitle: taskTitle)
        guard let field = root.firstDescendant(role: kAXTextAreaRole as String)
                ?? root.firstDescendant(role: kAXTextFieldRole as String)
        else { throw AccessibilityFallbackError.controlNotFound }
        guard AXUIElementSetAttributeValue(field.raw, kAXValueAttribute as CFString, text as CFTypeRef) == .success else {
            throw AccessibilityFallbackError.actionFailed("set-response")
        }
        guard let send = root.firstDescendant(
            role: kAXButtonRole as String,
            matchingAnyText: ["Send", "发送", "Submit", "提交"]
        ) else { throw AccessibilityFallbackError.controlNotFound }
        guard AXUIElementPerformAction(send.raw, kAXPressAction as CFString) == .success else {
            throw AccessibilityFallbackError.actionFailed("send-response")
        }
    }

    private func focusedTaskRoot(taskTitle: String) throws -> AXNode {
        let root = try trustedRoot()
        guard root.firstDescendant(containingText: taskTitle) != nil else {
            throw AccessibilityFallbackError.taskNotFound
        }
        return root
    }

    private func trustedRoot() throws -> AXNode {
        guard enabled() else { throw AccessibilityFallbackError.disabled }
        guard authorizer.isTrusted(promptIfNeeded: false) else {
            throw AccessibilityFallbackError.permissionDenied
        }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex").first else {
            throw AccessibilityFallbackError.codexNotRunning
        }
        return AXNode(raw: AXUIElementCreateApplication(app.processIdentifier), parent: nil)
    }

    private func containsAny(_ text: String, _ candidates: [String]) -> Bool {
        candidates.contains { text.contains($0.lowercased()) }
    }
}

private final class AXNode {
    let raw: AXUIElement
    weak var parent: AXNode?

    init(raw: AXUIElement, parent: AXNode?) {
        self.raw = raw
        self.parent = parent
    }

    var role: String? { stringAttribute(kAXRoleAttribute) }
    var text: String {
        [stringAttribute(kAXTitleAttribute), stringAttribute(kAXDescriptionAttribute), stringAttribute(kAXValueAttribute)]
            .compactMap { $0 }
            .joined(separator: " ")
    }
    var children: [AXNode] {
        guard let values = attribute(kAXChildrenAttribute) as? [AXUIElement] else { return [] }
        return values.map { AXNode(raw: $0, parent: self) }
    }
    var nearestContainer: AXNode? {
        var node = parent
        while let current = node {
            if [kAXWindowRole as String, kAXGroupRole as String].contains(current.role) { return current }
            node = current.parent
        }
        return parent
    }
    var flattenedText: String {
        ([text] + children.map(\.flattenedText)).joined(separator: " ")
    }

    func firstDescendant(role: String, exactText: String? = nil) -> AXNode? {
        firstDescendant { node in
            node.role == role && (exactText == nil || node.text == exactText)
        }
    }

    func firstDescendant(role: String, matchingAnyText values: [String]) -> AXNode? {
        firstDescendant { node in
            node.role == role && values.contains { node.text.localizedCaseInsensitiveContains($0) }
        }
    }

    func firstDescendant(containingText value: String) -> AXNode? {
        firstDescendant { $0.text.localizedCaseInsensitiveContains(value) }
    }

    private func firstDescendant(matching predicate: (AXNode) -> Bool) -> AXNode? {
        if predicate(self) { return self }
        for child in children {
            if let match = child.firstDescendant(matching: predicate) { return match }
        }
        return nil
    }

    private func stringAttribute(_ name: String) -> String? { attribute(name) as? String }

    private func attribute(_ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(raw, name as CFString, &value) == .success else { return nil }
        return value
    }
}
