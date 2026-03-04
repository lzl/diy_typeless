import Foundation

/// Entity representing the current application context.
public struct AppContext: Sendable {
    public let appName: String
    public let bundleIdentifier: String?
    public let url: String?

    public init(appName: String, bundleIdentifier: String?, url: String?) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.url = url
    }

    public var formatted: String {
        var parts = ["app=\(appName)"]
        if let url {
            parts.append("url=\(url)")
        }
        return parts.joined(separator: "; ")
    }
}

/// Repository protocol for capturing the current application context.
public protocol AppContextRepository: Sendable {
    /// Captures the current application context (frontmost app, URL, etc.)
    /// - Returns: The current AppContext
    func captureContext() -> AppContext
}
