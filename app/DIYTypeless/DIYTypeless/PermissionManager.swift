import AppKit
import AVFoundation

final class PermissionManager {
    func currentStatus() -> PermissionStatus {
        let accessibility = AXIsProcessTrusted()
        let inputMonitoring = CGPreflightListenEventAccess()
        let microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        return PermissionStatus(
            accessibility: accessibility,
            inputMonitoring: inputMonitoring,
            microphone: microphone
        )
    }

    @discardableResult
    func requestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    func requestInputMonitoring() -> Bool {
        return CGRequestListenEventAccess()
    }

    func requestMicrophone(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }

    func openAccessibilitySettings() {
        openSettingsPane(anchor: "Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        openSettingsPane(anchor: "Privacy_ListenEvent")
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

