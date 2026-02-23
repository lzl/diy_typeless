import Foundation
import AppKit

final class NSWorkspaceExternalLinkRepository: ExternalLinkRepository {
    func openConsole(for provider: ApiProvider) {
        if let url = URL(string: provider.consoleURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
