import AppKit
import AVFoundation

final class SystemPermissionRepository: PermissionRepository {
    var currentStatus: PermissionStatus {
        let accessibility = AXIsProcessTrusted()
        let microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        return PermissionStatus(
            accessibility: accessibility,
            microphone: microphone
        )
    }

    @discardableResult
    func requestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func requestMicrophone() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
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
