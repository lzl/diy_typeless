import Foundation

public struct CapsuleStateTransitionGuard: Sendable {
    public init() {}

    public func canTransition(from: CapsuleState, to: CapsuleState) -> Bool {
        let fromPhase = Phase(from)
        let toPhase = Phase(to)

        if fromPhase == toPhase {
            return true
        }

        let allowed = transitionTable[fromPhase] ?? []
        return allowed.contains(toPhase)
    }
}

private enum Phase: Hashable {
    case hidden
    case recording
    case transcribing
    case polishing
    case processingCommand
    case canceled
    case done
    case error

    init(_ state: CapsuleState) {
        switch state {
        case .hidden:
            self = .hidden
        case .recording:
            self = .recording
        case .transcribing:
            self = .transcribing
        case .polishing:
            self = .polishing
        case .processingCommand:
            self = .processingCommand
        case .canceled:
            self = .canceled
        case .done:
            self = .done
        case .error:
            self = .error
        }
    }
}

private let transitionTable: [Phase: Set<Phase>] = [
    .hidden: [.recording, .error],
    .recording: [.hidden, .transcribing, .canceled, .error],
    .transcribing: [.polishing, .processingCommand, .hidden, .canceled, .error],
    .polishing: [.done, .hidden, .canceled, .error],
    .processingCommand: [.hidden, .canceled, .error],
    .canceled: [.hidden, .recording, .error],
    .done: [.hidden, .recording, .error],
    .error: [.hidden, .recording, .error]
]
