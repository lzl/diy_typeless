import Foundation

protocol ApiKeyRepository: Sendable {
    func loadKey(for provider: ApiProvider) -> String?
    func saveKey(_ key: String, for provider: ApiProvider) throws
    func deleteKey(for provider: ApiProvider) throws
}
