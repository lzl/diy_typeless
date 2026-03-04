import Foundation

/// Entity representing required macOS permissions.
public struct PermissionStatus: Sendable {
    public let accessibility: Bool
    public let microphone: Bool

    public init(accessibility: Bool, microphone: Bool) {
        self.accessibility = accessibility
        self.microphone = microphone
    }

    public var allGranted: Bool {
        accessibility && microphone
    }
}
