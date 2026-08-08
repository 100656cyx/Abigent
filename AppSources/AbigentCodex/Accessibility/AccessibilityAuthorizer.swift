@preconcurrency import ApplicationServices
import Foundation

public protocol AccessibilityAuthorizing: Sendable {
    func isTrusted(promptIfNeeded: Bool) -> Bool
}

public struct SystemAccessibilityAuthorizer: AccessibilityAuthorizing {
    public init() {}

    public func isTrusted(promptIfNeeded: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: promptIfNeeded] as CFDictionary)
    }
}
