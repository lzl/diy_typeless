import Foundation
import Security

final class ApiKeyStore {
    private let service = "com.lizunlong.DIYTypeless"
    private let combinedAccount = "api_keys"
    // Legacy identifiers for migration
    private let legacyService = "com.diytypeless.api"
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

        // Try loading from combined storage (current service) first
        if let data = loadDataFromKeychain(account: combinedAccount),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            cachedGroqKey = dict["groq"]
            cachedGeminiKey = dict["gemini"]
        } else if let data = loadDataFromKeychain(account: combinedAccount, service: legacyService),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            // Migrate from legacy service (com.diytypeless.api) combined storage
            cachedGroqKey = dict["groq"]
            cachedGeminiKey = dict["gemini"]
            if saveAllKeysInternal() {
                deleteFromKeychain(account: combinedAccount, service: legacyService)
            }
        } else {
            // Migrate from legacy separate accounts (oldest format)
            cachedGroqKey = loadStringFromKeychain(account: legacyGroqAccount, service: legacyService)
            cachedGeminiKey = loadStringFromKeychain(account: legacyGeminiAccount, service: legacyService)

            if cachedGroqKey != nil || cachedGeminiKey != nil {
                if saveAllKeysInternal() {
                    deleteFromKeychain(account: legacyGroqAccount, service: legacyService)
                    deleteFromKeychain(account: legacyGeminiAccount, service: legacyService)
                }
            }
        }

        cacheLoaded = true
    }

    func saveGroqKey(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        cachedGroqKey = key
        _ = saveAllKeysInternal()
    }

    func saveGeminiKey(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        cachedGeminiKey = key
        _ = saveAllKeysInternal()
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

    private func loadDataFromKeychain(account: String, service svc: String? = nil) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc ?? service,
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

    private func loadStringFromKeychain(account: String, service svc: String? = nil) -> String? {
        guard let data = loadDataFromKeychain(account: account, service: svc) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(account: String, service svc: String? = nil) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc ?? service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
