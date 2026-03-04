import Foundation

/// Entity representing the current application context.
struct AppContext: Sendable {
    let appName: String
    let bundleIdentifier: String?
    let url: String?

    var formatted: String {
        var parts = ["app=\(appName)"]
        if let url {
            parts.append("url=\(url)")
        }
        return parts.joined(separator: "; ")
    }
}

/// Repository protocol for capturing the current application context.
protocol AppContextRepository: Sendable {
    /// Captures the current application context (frontmost app, URL, etc.)
    /// - Returns: The current AppContext
    func captureContext() -> AppContext
}
