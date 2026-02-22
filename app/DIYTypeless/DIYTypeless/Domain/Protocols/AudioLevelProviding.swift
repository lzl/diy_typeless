import Foundation

/// Protocol for providing audio level data to waveform visualization
/// Enables testability by allowing mock implementations
protocol AudioLevelProviding: AnyObject {
    /// Current audio levels array (typically 20 values between 0.0 and 1.0)
    var levels: [CGFloat] { get }
    
    /// Start monitoring audio levels
    func start()
    
    /// Stop monitoring audio levels
    func stop()
}
