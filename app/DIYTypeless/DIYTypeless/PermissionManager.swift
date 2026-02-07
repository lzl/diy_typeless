import AppKit
import AVFoundation

final class PermissionManager {
    func currentStatus() -> PermissionStatus {
        let accessibility = AXIsProcessTrusted()
        let microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        return PermissionStatus(
            accessibility: accessibility,
            microphone: microphone
        )
    }

    @discardableResult
    func requestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func requestMicrophone(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }

    func openAccessibilitySettings() {
        openSettingsPane(anchor: "Privacy_Accessibility")
    }

    func openMicrophoneSettings() {
        openSettingsPane(anchor: "Privacy_Microphone")
    }

    private func openSettingsPane(anchor: String) {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
