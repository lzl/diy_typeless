import Foundation

/// Protocol for GetSelectedTextUseCase.
protocol GetSelectedTextUseCaseProtocol: Sendable {
    func execute() async -> SelectedTextContext
}

/// Use case for retrieving selected text from the active application.
/// Single Responsibility: Only retrieves selected text, nothing else.
final class GetSelectedTextUseCase: GetSelectedTextUseCaseProtocol {
    private let repository: SelectedTextRepository

    init(repository: SelectedTextRepository = AccessibilitySelectedTextRepository()) {
        self.repository = repository
    }

    func execute() async -> SelectedTextContext {
        await repository.getSelectedText()
    }
}
