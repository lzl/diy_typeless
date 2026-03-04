import Foundation

/// Entity representing the context of selected text in the active application.
/// This is an anemic entity containing only data with no business logic.
public struct SelectedTextContext: Sendable {
    public let text: String?
    public let isEditable: Bool
    public let isSecure: Bool
    public let applicationName: String

    public init(
        text: String?,
        isEditable: Bool,
        isSecure: Bool,
        applicationName: String
    ) {
        self.text = text
        self.isEditable = isEditable
        self.isSecure = isSecure
        self.applicationName = applicationName
    }

    /// Pure data computation, no business logic
    public var hasSelection: Bool {
        guard let text = text else { return false }
        return !text.isEmpty
    }
}

extension SelectedTextContext {
    public static var empty: SelectedTextContext {
        SelectedTextContext(
            text: nil,
            isEditable: false,
            isSecure: false,
            applicationName: ""
        )
    }
}
