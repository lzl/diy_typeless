import Foundation

/// Entity representing required macOS permissions.
struct PermissionStatus: Sendable {
    let accessibility: Bool
    let microphone: Bool

    var allGranted: Bool {
        accessibility && microphone
    }
}
