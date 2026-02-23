import Foundation

protocol ExternalLinkRepository: Sendable {
    func openConsole(for provider: ApiProvider)
}
