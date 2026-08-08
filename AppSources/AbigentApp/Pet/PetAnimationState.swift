import AbigentCore
import Foundation

enum PetAnimationState: Equatable {
    case idle
    case working
    case needsInput
    case completed
    case disconnected

    static func aggregate(_ tasks: [AgentTask]) -> PetAnimationState {
        if tasks.contains(where: { $0.state == .needsInput }) { return .needsInput }
        if tasks.contains(where: { $0.state == .connectionUnknown }) { return .disconnected }
        if tasks.contains(where: { $0.state == .working }) { return .working }
        if tasks.contains(where: { $0.state == .completed && Date().timeIntervalSince($0.updatedAt) < 8 }) {
            return .completed
        }
        return .idle
    }
}
