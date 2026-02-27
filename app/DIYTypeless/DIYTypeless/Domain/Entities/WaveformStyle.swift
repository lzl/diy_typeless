import Foundation

/// Defines the available waveform visualization styles
enum WaveformStyle: String, CaseIterable, Sendable {
    case fluid = "fluid"
    case bars = "bars"
    case disabled = "disabled"

    var displayName: String {
        switch self {
        case .fluid: return "Fluid"
        case .bars: return "Bars"
        case .disabled: return "Disabled"
        }
    }
}
