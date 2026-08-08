import AbigentCore
import Foundation

enum PetHoverState {
    static func featuredTask(_ tasks: [AgentTask]) -> AgentTask? {
        let sorted = tasks.sorted { $0.updatedAt > $1.updatedAt }
        return sorted.first { $0.state == .needsInput }
            ?? sorted.first { $0.state == .working }
            ?? sorted.first { [.completed, .failed, .cancelled].contains($0.state) }
            ?? sorted.first { $0.state == .connectionUnknown }
    }
}
