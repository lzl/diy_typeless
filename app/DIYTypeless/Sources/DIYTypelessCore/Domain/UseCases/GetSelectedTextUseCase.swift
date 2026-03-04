import Foundation

/// Protocol for GetSelectedTextUseCase.
public protocol GetSelectedTextUseCaseProtocol: Sendable {
    func execute() async -> SelectedTextContext
}

/// Use case for retrieving selected text from the active application.
/// Single Responsibility: Only retrieves selected text, nothing else.
public final class GetSelectedTextUseCase: GetSelectedTextUseCaseProtocol {
    private let repository: SelectedTextRepository

    public init(repository: SelectedTextRepository) {
        self.repository = repository
    }

    public func execute() async -> SelectedTextContext {
        await repository.getSelectedText()
    }
}
