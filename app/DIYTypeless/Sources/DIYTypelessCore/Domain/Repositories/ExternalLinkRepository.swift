import Foundation

public protocol ExternalLinkRepository: Sendable {
    func openConsole(for provider: ApiProvider)
}
