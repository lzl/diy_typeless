import SwiftUI

/// Observable settings for waveform visualization
/// Uses computed properties with get/set (NOT didSet) for UserDefaults persistence
@MainActor
@Observable
final class WaveformSettings {
    private let defaults = UserDefaults.standard
    private let styleKey = "waveformStyle"

    /// Cached style value to avoid repeated UserDefaults reads
    private var cachedStyle: WaveformStyle?

    var selectedStyle: WaveformStyle {
        get {
            // Return cached value if available
            if let cached = cachedStyle {
                return cached
            }
            // Read from UserDefaults and cache
            let rawValue = defaults.string(forKey: styleKey)
            let style = WaveformStyle(rawValue: rawValue ?? "") ?? .fluid
            cachedStyle = style
            return style
        }
        set {
            // Update cache and UserDefaults atomically
            cachedStyle = newValue
            defaults.set(newValue.rawValue, forKey: styleKey)
        }
    }

    init() {}

    /// Clear cache (useful for testing)
    func clearCache() {
        cachedStyle = nil
    }
}
