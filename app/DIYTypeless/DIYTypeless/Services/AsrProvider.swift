import Foundation

/// ASR provider enum - compatible with Rust FFI
public enum AsrProvider: Int32, CaseIterable, Identifiable {
    case groq = 0
    case local = 1

    public var id: Int32 { rawValue }

    var displayName: String {
        switch self {
        case .groq: return "Groq Whisper (Cloud)"
        case .local: return "Qwen3-ASR (Local)"
        }
    }

    var description: String {
        switch self {
        case .groq: return "Uses Groq API, requires internet connection and API key"
        case .local: return "Uses local Qwen3-ASR model, fully offline, faster startup"
        }
    }
}

/// Manages ASR provider settings
class AsrSettings {
    static let shared = AsrSettings()

    private let defaults = UserDefaults.standard
    private let asrProviderKey = "asrProvider"

    var currentProvider: AsrProvider {
        get {
            let rawValue = defaults.integer(forKey: asrProviderKey)
            return AsrProvider(rawValue: Int32(rawValue)) ?? .groq
        }
        set {
            defaults.set(Int(newValue.rawValue), forKey: asrProviderKey)
        }
    }

    /// Check if current ASR is available
    var isCurrentProviderAvailable: Bool {
        switch currentProvider {
        case .groq:
            // Groq requires API key
            let keyStore = ApiKeyStore()
            keyStore.preloadKeys()
            return !(keyStore.loadGroqKey() ?? "").isEmpty
        case .local:
            // Local ASR requires model
            return LocalAsrManager.shared.isModelLoaded
        }
    }
}
