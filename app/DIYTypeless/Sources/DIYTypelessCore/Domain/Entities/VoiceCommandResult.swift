import Foundation

/// Entity representing the result of processing a voice command.
public struct VoiceCommandResult: Sendable {
    public let processedText: String
    public let action: CommandAction

    public init(processedText: String, action: CommandAction) {
        self.processedText = processedText
        self.action = action
    }
}

/// Enum representing possible actions to take with the processed text.
public enum CommandAction: Sendable {
    case replaceSelection
    case insertAtCursor
    case copyToClipboard
}
