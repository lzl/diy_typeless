import Foundation

/// Test data fixtures for waveform tests
enum WaveformTestData {
    static let silence: [Double] = [0.0, 0.0, 0.0, 0.0, 0.0]
    static let normal: [Double] = [0.25, 0.5, 0.75, 0.5, 0.25]
    static let maximum: [Double] = [1.0, 1.0, 1.0, 1.0, 1.0]
    static let decay: [Double] = [1.0, 0.8, 0.6, 0.4, 0.2, 0.1]
    static let empty: [Double] = []
    static let rapidAlternation: [Double] = [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
    static let largeArray: [Double] = Array(repeating: 0.5, count: 1000)
    static let singleValue: [Double] = [0.5]
    static let twentyBars: [Double] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0,
                                        0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.0]
}
