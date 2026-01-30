import Foundation
import Security

final class ApiKeyStore {
    private let service = "com.diytypeless.api"
    private let groqAccount = "groq_api_key"
    private let geminiAccount = "gemini_api_key"

    func saveGroqKey(_ key: String) {
        save(key: key, account: groqAccount)
    }

    func saveGeminiKey(_ key: String) {
        save(key: key, account: geminiAccount)
    }

    func loadGroqKey() -> String? {
        load(account: groqAccount)
    }

    func loadGeminiKey() -> String? {
        load(account: geminiAccount)
    }

    @discardableResult
    private func save(key: String, account: String) -> Bool {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            return updateStatus == errSecSuccess
        } else {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            return addStatus == errSecSuccess
        }
    }

    private func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataRef: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &dataRef)
        guard status == errSecSuccess, let data = dataRef as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

