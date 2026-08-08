public enum NotificationDecision: Sendable, Equatable {
    case none
    case attention
    case completed
    case failed
}

public enum NotificationPolicy {
    public static func decision(previous: TaskState, current task: AgentTask) -> NotificationDecision {
        guard !task.muted, previous != task.state else { return .none }

        switch task.state {
        case .needsInput: return .attention
        case .completed: return .completed
        case .failed: return .failed
        case .discovered, .working, .cancelled, .connectionUnknown: return .none
        }
    }
}
