import Foundation

enum OnboardingState: Equatable {
    case detecting
    case codexMissing
    case hookNotInstalled
    case restartRequired(installedAt: Date)
    case waitingForSessionStart
    case ready
    case failed(message: String)
}
