import Foundation

final class ApplicationStartupGate {
    private var started = false

    func begin() -> Bool {
        guard !started else { return false }
        started = true
        return true
    }
}
