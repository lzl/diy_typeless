import Foundation
import DIYTypelessCore

struct OnboardingChecklistItem: Equatable {
    let systemName: String
    let title: String
    let detail: String
}

enum OnboardingWelcomeContent {
    static let setupChecklistTitle = "What you'll set up"

    static let setupChecklistItems: [OnboardingChecklistItem] = [
        .init(
            systemName: "hand.raised.fill",
            title: "Grant permissions",
            detail: "Allow microphone and accessibility access."
        ),
        .init(
            systemName: "key.fill",
            title: "Add API keys",
            detail: "Enter your Groq and Gemini keys."
        )
    ]
}

enum CompletionPracticeLayout {
    static let lineCount = 3
}

enum CompletionPracticeGuidanceDisplayPolicy {
    static let successHoldDuration: TimeInterval = 2.4
}

struct CompletionPracticeGuidance: Equatable {
    enum Tone: Equatable {
        case neutral
        case active
        case success
        case error
    }

    let text: String
    let tone: Tone

    static func make(for capsuleState: CapsuleState) -> Self {
        switch capsuleState {
        case .hidden:
            return .init(
                text: "Click in the box, hold Fn, speak, then release.",
                tone: .neutral
            )
        case .recording:
            return .init(text: "Listening... keep holding Fn.", tone: .active)
        case .transcribing:
            return .init(text: "Transcribing your speech...", tone: .active)
        case .polishing:
            return .init(text: "Polishing the text...", tone: .active)
        case .processingCommand:
            return .init(text: "Processing your command...", tone: .active)
        case .canceled:
            return .init(text: "Canceled. Click in the box and try again.", tone: .neutral)
        case .done(.pasted):
            return .init(text: "Inserted above. Try another one or finish.", tone: .success)
        case .done(.copied):
            return .init(text: "Copied to clipboard. Press Cmd+V in the box.", tone: .success)
        case .error(let error):
            return .init(text: error.message, tone: .error)
        }
    }
}

enum CapsuleFocusCapturePolicy {
    static func shouldCaptureKeyFocus(
        capsuleState: CapsuleState,
        isResultLayerVisible: Bool,
        hasOtherKeyWindow: Bool
    ) -> Bool {
        if hasOtherKeyWindow {
            return false
        }

        if isResultLayerVisible {
            return true
        }

        switch capsuleState {
        case .recording, .transcribing, .polishing, .processingCommand:
            return true
        case .hidden, .canceled, .done, .error:
            return false
        }
    }
}

enum PrimaryButtonPalette {
    static let hoverFillHex = "#5D7871"
}
