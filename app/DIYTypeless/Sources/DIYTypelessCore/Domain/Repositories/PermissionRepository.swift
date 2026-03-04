import Foundation

public protocol PermissionRepository: Sendable {
    /// Current app permission status from the domain entity.
    var currentStatus: PermissionStatus { get }
    func requestAccessibility() -> Bool
    func requestMicrophone() async -> Bool
    func openAccessibilitySettings()
    func openMicrophoneSettings()
}
