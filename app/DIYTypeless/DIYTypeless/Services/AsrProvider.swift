import Foundation

/// ASR 提供商枚举
enum AsrProvider: String, CaseIterable, Identifiable {
    case groq = "groq"
    case local = "local"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groq: return "Groq Whisper (云端)"
        case .local: return "Qwen3-ASR (本地)"
        }
    }

    var description: String {
        switch self {
        case .groq: return "使用 Groq API，需要网络连接和 API Key"
        case .local: return "使用本地 Qwen3-ASR 模型，完全离线，启动更快"
        }
    }
}

/// 管理 ASR 提供商设置
class AsrSettings {
    static let shared = AsrSettings()

    private let defaults = UserDefaults.standard
    private let asrProviderKey = "asrProvider"

    var currentProvider: AsrProvider {
        get {
            let rawValue = defaults.string(forKey: asrProviderKey) ?? AsrProvider.groq.rawValue
            return AsrProvider(rawValue: rawValue) ?? .groq
        }
        set {
            defaults.set(newValue.rawValue, forKey: asrProviderKey)
        }
    }

    /// 检查当前 ASR 是否可用
    var isCurrentProviderAvailable: Bool {
        switch currentProvider {
        case .groq:
            // Groq 需要 API Key
            let keyStore = ApiKeyStore()
            keyStore.preloadKeys()
            return !(keyStore.loadGroqKey() ?? "").isEmpty
        case .local:
            // 本地 ASR 需要模型
            return LocalAsrManager.shared.isModelLoaded
        }
    }
}
