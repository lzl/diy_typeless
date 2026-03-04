import Foundation

/// Entity representing the result of processing a voice command.
struct VoiceCommandResult: Sendable {
    let processedText: String
    let action: CommandAction
}

/// Enum representing possible actions to take with the processed text.
enum CommandAction: Sendable {
    case replaceSelection
    case insertAtCursor
    case copyToClipboard
}
