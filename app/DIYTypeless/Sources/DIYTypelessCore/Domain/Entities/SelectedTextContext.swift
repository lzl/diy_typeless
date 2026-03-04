import Foundation

/// Entity representing the context of selected text in the active application.
/// This is an anemic entity containing only data with no business logic.
struct SelectedTextContext: Sendable {
    let text: String?
    let isEditable: Bool
    let isSecure: Bool
    let applicationName: String

    /// Pure data computation, no business logic
    var hasSelection: Bool {
        guard let text = text else { return false }
        return !text.isEmpty
    }
}

extension SelectedTextContext {
    static var empty: SelectedTextContext {
        SelectedTextContext(
            text: nil,
            isEditable: false,
            isSecure: false,
            applicationName: ""
        )
    }
}
