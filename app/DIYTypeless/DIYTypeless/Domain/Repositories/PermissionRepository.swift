import Foundation

protocol PermissionRepository: Sendable {
    var currentStatus: PermissionStatus { get }
    func requestAccessibility() -> Bool
    func requestMicrophone() async -> Bool
    func openAccessibilitySettings()
    func openMicrophoneSettings()
}
