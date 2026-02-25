import AppKit

/// Repository implementation that retrieves selected text using macOS Accessibility API.
/// Executes API calls on background thread to avoid blocking MainActor.
final class AccessibilitySelectedTextRepository: SelectedTextRepository {
    func getSelectedText() async -> SelectedTextContext {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let context = self.performAccessibilityQuery()
                continuation.resume(returning: context)
            }
        }
    }

    private func performAccessibilityQuery() -> SelectedTextContext {
        let systemWide = AXUIElementCreateSystemWide()

        // Get current application name
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        print("[Accessibility] App name: \(appName)")

        // Get focused element
        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success, let element = focusedElement else {
            print("[Accessibility] Failed to get focused element, result: \(focusResult)")
            return SelectedTextContext(
                text: nil,
                isEditable: false,
                isSecure: false,
                applicationName: appName
            )
        }

        let axElement = element as! AXUIElement
        print("[Accessibility] Got focused element")

        // Check if secure text field (password)
        let isSecure = checkIfSecureTextField(axElement)
        print("[Accessibility] isSecure: \(isSecure)")
        if isSecure {
            return SelectedTextContext(
                text: nil,
                isEditable: false,
                isSecure: true,
                applicationName: appName
            )
        }

        // Check if editable
        let isEditable = checkIfEditable(axElement)
        print("[Accessibility] isEditable: \(isEditable)")

        // Get selected text
        let selectedText = readSelectedText(from: axElement)
        print("[Accessibility] Selected text: '\(selectedText ?? "nil")'")

        return SelectedTextContext(
            text: selectedText,
            isEditable: isEditable,
            isSecure: false,
            applicationName: appName
        )
    }

    private func readSelectedText(from element: AXUIElement) -> String? {
        // Method 1: Direct kAXSelectedTextAttribute
        if let text = readSelectedTextAttribute(from: element) {
            return text.isEmpty ? nil : text
        }

        // Method 2: kAXValueAttribute + kAXSelectedTextRangeAttribute
        if let text = readValueWithSelectedRange(from: element) {
            return text.isEmpty ? nil : text
        }

        return nil
    }

    private func readSelectedTextAttribute(from element: AXUIElement) -> String? {
        var selectedValue: CFTypeRef?
        let selectedResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        )

        print("[Accessibility] kAXSelectedTextAttribute result: \(selectedResult)")

        guard selectedResult == .success,
              let text = selectedValue as? String else {
            print("[Accessibility] kAXSelectedTextAttribute failed or nil")
            return nil
        }

        print("[Accessibility] kAXSelectedTextAttribute text: '\(text)'")
        return text
    }

    private func readValueWithSelectedRange(from element: AXUIElement) -> String? {
        // Read full text value
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &valueRef
        ) == .success,
              let fullText = valueRef as? String else {
            return nil
        }

        // Read selected range
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeRef
        ) == .success else {
            return nil
        }

        // Convert CFRange to NSRange
        var range = CFRange(location: 0, length: 0)
        AXValueGetValue(rangeRef as! AXValue, AXValueType(rawValue: kAXValueCFRangeType) ?? AXValueType(rawValue: 0)!, &range)

        // Validate range
        guard range.location >= 0, range.length >= 0 else {
            return nil
        }

        let nsRange = NSRange(location: range.location, length: range.length)

        // Extract substring
        guard let swiftRange = Range(nsRange, in: fullText) else {
            return nil
        }

        return String(fullText[swiftRange])
    }

    private func checkIfSecureTextField(_ element: AXUIElement) -> Bool {
        // Method 1: Check role for secure text field
        var roleValue: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &roleValue
        )

        if roleResult == .success,
           let role = roleValue as? String,
           role == "AXSecureTextField" {
            return true
        }

        // Method 2: Check subrole
        var subroleValue: CFTypeRef?
        let subroleResult = AXUIElementCopyAttributeValue(
            element,
            kAXSubroleAttribute as CFString,
            &subroleValue
        )

        if subroleResult == .success,
           let subrole = subroleValue as? String,
           subrole.lowercased().contains("secure") {
            return true
        }

        return false
    }

    private func checkIfEditable(_ element: AXUIElement) -> Bool {
        // Method 1: Check AXEditable attribute
        var editableValue: CFTypeRef?
        let editableResult = AXUIElementCopyAttributeValue(
            element,
            "AXEditable" as CFString,
            &editableValue
        )

        if editableResult == .success,
           let isEditable = editableValue as? Bool {
            return isEditable
        }

        // Method 2: Check role
        var roleValue: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &roleValue
        )

        if roleResult == .success,
           let role = roleValue as? String {
            let editableRoles = [
                kAXTextFieldRole as String,
                kAXTextAreaRole as String,
                "AXSearchField",
                kAXComboBoxRole as String
            ]
            return editableRoles.contains(role)
        }

        return false
    }
}
