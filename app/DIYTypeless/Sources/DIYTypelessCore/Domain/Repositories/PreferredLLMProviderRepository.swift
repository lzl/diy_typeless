import Foundation

public protocol PreferredLLMProviderRepository: Sendable {
    func loadProvider() -> ApiProvider
    func saveProvider(_ provider: ApiProvider)
}
