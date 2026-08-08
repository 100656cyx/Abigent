import XCTest
@testable import AbigentCodex

private struct FakeAuthorizer: AccessibilityAuthorizing {
    let trusted: Bool
    func isTrusted(promptIfNeeded: Bool) -> Bool { trusted }
}

final class CodexAccessibilityFallbackTests: XCTestCase {
    func testDisabledFallbackDoesNotRequestSystemPermission() {
        let fallback = CodexAccessibilityFallback(authorizer: FakeAuthorizer(trusted: true), enabled: { false })
        XCTAssertFalse(fallback.requestPermission())
        XCTAssertThrowsError(try fallback.visibleState(taskTitle: "Task")) { error in
            XCTAssertEqual(error as? AccessibilityFallbackError, .disabled)
        }
    }

    func testDeniedPermissionIsExplicit() {
        let fallback = CodexAccessibilityFallback(authorizer: FakeAuthorizer(trusted: false), enabled: { true })
        XCTAssertThrowsError(try fallback.visibleState(taskTitle: "Task")) { error in
            XCTAssertEqual(error as? AccessibilityFallbackError, .permissionDenied)
        }
    }
}
