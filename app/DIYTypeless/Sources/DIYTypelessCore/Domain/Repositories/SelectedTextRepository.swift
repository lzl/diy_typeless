import Foundation

/// Repository protocol for retrieving selected text from the active application.
/// Following project convention, protocol names do not have "Protocol" suffix.
public protocol SelectedTextRepository: Sendable {
    func getSelectedText() async -> SelectedTextContext
}
