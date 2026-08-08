import Foundation

public enum TaskReducerError: Error, Equatable {
    case taskIdentityMismatch(expected: GlobalTaskID, received: GlobalTaskID)
    case connectionEventHasNoTask
}

public enum TaskReducer {
    public static func reduce(current: AgentTask, observed: ObservedAgentEvent) throws -> AgentTask {
        if let currentProvenance = current.provenance,
           currentProvenance > observed.provenance {
            return current
        }
        if current.provenance == observed.provenance,
           let currentObservedAt = current.observedAt,
           observed.observedAt < currentObservedAt {
            return current
        }

        var next = try reduce(current: current, event: observed.event)
        guard next != current || current.provenance == nil else { return current }
        next.provenance = observed.provenance
        next.observedAt = observed.observedAt
        return next
    }

    public static func reduce(current: AgentTask, event: AgentEvent) throws -> AgentTask {
        switch event {
        case .connectionChanged:
            throw TaskReducerError.connectionEventHasNoTask
        case let .snapshot(snapshot):
            try requireMatching(current.id, snapshot.id)
            return snapshot.updatedAt >= current.updatedAt ? snapshot : current
        case let .stateChanged(id, state, updatedAt):
            try requireMatching(current.id, id)
            guard updatedAt >= current.updatedAt else { return current }
            var next = current
            next.state = state
            next.updatedAt = updatedAt
            if state == .working {
                next.attentionRequest = nil
                next.result = nil
                next.completedAt = nil
            }
            if state == .completed || state == .failed || state == .cancelled {
                next.completedAt = updatedAt
            }
            return next
        case let .attention(id, request):
            try requireMatching(current.id, id)
            var next = current
            next.state = .needsInput
            next.attentionRequest = request
            return next
        case let .result(id, result):
            try requireMatching(current.id, id)
            var next = current
            next.result = result
            return next
        }
    }

    private static func requireMatching(_ expected: GlobalTaskID, _ received: GlobalTaskID) throws {
        guard expected == received else {
            throw TaskReducerError.taskIdentityMismatch(expected: expected, received: received)
        }
    }
}
