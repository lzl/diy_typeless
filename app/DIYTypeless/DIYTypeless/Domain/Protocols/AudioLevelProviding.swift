import Foundation

/// Protocol for providing audio level data to waveform visualizations
/// Uses Double (not CGFloat) to maintain Domain layer purity
protocol AudioLevelProviding: AnyObject, Sendable {
    /// Current audio levels as normalized values (0.0...1.0)
    var levels: [Double] { get }

    /// AsyncStream for real-time audio level updates
    var levelsStream: AsyncStream<[Double]> { get }

    /// Start monitoring audio levels
    func startMonitoring() throws

    /// Stop monitoring audio levels
    func stopMonitoring() async
}
