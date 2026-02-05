import Foundation
import Security

final class ApiKeyStore {
    private let service = "com.diytypeless.api"
    private let combinedAccount = "api_keys"
    // Legacy accounts for migration
    private let legacyGroqAccount = "groq_api_key"
    private let legacyGeminiAccount = "gemini_api_key"

    // Thread synchronization lock for cache access
    private let lock = NSLock()
    private var cachedGroqKey: String?
    private var cachedGeminiKey: String?
    private var cacheLoaded = false

    /// Call once at startup to preload all keys into memory cache.
    /// This triggers only one Keychain authorization prompt.
    func preloadKeys() {
        lock.lock()
        defer { lock.unlock() }

        guard !cacheLoaded else { return }

        // Try loading from combined storage first
        if let data = loadDataFromKeychain(account: combinedAccount),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            cachedGroqKey = dict["groq"]
            cachedGeminiKey = dict["gemini"]
        } else {
            // Migrate from legacy separate accounts
            cachedGroqKey = loadStringFromKeychain(account: legacyGroqAccount)
            cachedGeminiKey = loadStringFromKeychain(account: legacyGeminiAccount)

            // If we found legacy keys, migrate to combined storage
            // Only delete legacy keys after confirming save succeeded
            if cachedGroqKey != nil || cachedGeminiKey != nil {
                if saveAllKeysInternal() {
                    deleteFromKeychain(account: legacyGroqAccount)
                    deleteFromKeychain(account: legacyGeminiAccount)
                }
            }
        }

        cacheLoaded = true
    }

    func saveGroqKey(_ key: String) {
        lock.lock()
        cachedGroqKey = key
        _ = saveAllKeysInternal()
        lock.unlock()
    }

    func saveGeminiKey(_ key: String) {
        lock.lock()
        cachedGeminiKey = key
        _ = saveAllKeysInternal()
        lock.unlock()
    }

    func loadGroqKey() -> String? {
        ensureCacheLoaded()
        lock.lock()
        defer { lock.unlock() }
        return cachedGroqKey
    }

    func loadGeminiKey() -> String? {
        ensureCacheLoaded()
        lock.lock()
        defer { lock.unlock() }
        return cachedGeminiKey
    }

    private func ensureCacheLoaded() {
        lock.lock()
        let needsLoad = !cacheLoaded
        lock.unlock()
        if needsLoad {
            preloadKeys()
        }
    }

    /// Internal save method, must be called with lock held.
    /// Returns true if save succeeded.
    @discardableResult
    private func saveAllKeysInternal() -> Bool {
        var dict: [String: String] = [:]
        if let groq = cachedGroqKey, !groq.isEmpty {
            dict["groq"] = groq
        }
        if let gemini = cachedGeminiKey, !gemini.isEmpty {
            dict["gemini"] = gemini
        }
        guard let data = try? JSONEncoder().encode(dict) else { return false }
        return saveDataToKeychain(data: data, account: combinedAccount)
    }

    @discardableResult
    private func saveDataToKeychain(data: Data, account: String) -> Bool {
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

    private func loadDataFromKeychain(account: String) -> Data? {
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
        return data
    }

    private func loadStringFromKeychain(account: String) -> String? {
        guard let data = loadDataFromKeychain(account: account) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
