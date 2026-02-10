import AppKit

struct AppContext {
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

final class AppContextDetector {

    private static let browserBundles: Set<String> = [
        "com.google.Chrome",
        "com.apple.Safari",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "company.thebrowser.Browser", // Arc
    ]

    func captureContext() -> AppContext {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return AppContext(appName: "Unknown", bundleIdentifier: nil, url: nil)
        }

        let appName = frontApp.localizedName ?? "Unknown"
        let bundleId = frontApp.bundleIdentifier

        var url: String?
        if let bundleId, Self.browserBundles.contains(bundleId) {
            let pid = frontApp.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)
            url = browserURL(appElement: appElement, bundleId: bundleId)
        }

        return AppContext(appName: appName, bundleIdentifier: bundleId, url: url)
    }

    // MARK: - Browser URL via Accessibility API

    private func browserURL(appElement: AXUIElement, bundleId: String) -> String? {
        if bundleId == "com.apple.Safari" {
            return safariURL(appElement: appElement)
        }
        return chromiumURL(appElement: appElement)
    }

    private func safariURL(appElement: AXUIElement) -> String? {
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )
        guard result == .success, let window = focusedWindow else {
            return nil
        }

        var docValue: CFTypeRef?
        let docResult = AXUIElementCopyAttributeValue(
            window as! AXUIElement,
            "AXDocument" as CFString,
            &docValue
        )
        if docResult == .success, let urlString = docValue as? String {
            return urlString
        }
        return nil
    }

    private func chromiumURL(appElement: AXUIElement) -> String? {
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )
        guard result == .success, let window = focusedWindow else {
            return nil
        }
        var visited = 0
        return findAddressBar(element: window as! AXUIElement, maxDepth: 15, visited: &visited)
    }

    private static let addressKeywords = ["address", "location", "url", "地址", "网址"]
    private static let skipRoles: Set<String> = ["AXWebArea"]

    private func findAddressBar(element: AXUIElement, maxDepth: Int, visited: inout Int) -> String? {
        if maxDepth <= 0 || visited > 500 { return nil }

        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXChildrenAttribute as CFString,
            &childrenRef
        )
        guard result == .success, let children = childrenRef as? [AXUIElement] else {
            return nil
        }

        for child in children {
            visited += 1
            if visited > 500 { return nil }

            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            let role = roleRef as? String ?? ""

            if role == kAXTextFieldRole as String || role == kAXComboBoxRole as String {
                var descRef: CFTypeRef?
                AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &descRef)
                let desc = (descRef as? String)?.lowercased() ?? ""

                if Self.addressKeywords.contains(where: { desc.contains($0) }) {
                    var valueRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &valueRef)
                    if let value = valueRef as? String, !value.isEmpty {
                        return value
                    }
                }
            }

            if !Self.skipRoles.contains(role) {
                if let found = findAddressBar(element: child, maxDepth: maxDepth - 1, visited: &visited) {
                    return found
                }
            }
        }

        return nil
    }
}
