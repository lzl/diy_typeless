import AppKit

/// Repository implementation that retrieves selected text using macOS Accessibility API.
/// Executes API calls on background thread to avoid blocking MainActor.
final class AccessibilitySelectedTextRepository: SelectedTextRepository {
    func getSelectedText() async -> SelectedTextContext {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Try Accessibility API first
                var context = self.performAccessibilityQuery()

                // If no text found via AX API, try clipboard method (for browsers like Chrome)
                if !context.hasSelection {
                    if let clipboardText = self.getSelectedTextViaClipboard(),
                       !clipboardText.isEmpty {
                        context = SelectedTextContext(
                            text: clipboardText,
                            isEditable: context.isEditable,
                            isSecure: context.isSecure,
                            applicationName: context.applicationName
                        )
                    }
                }

                continuation.resume(returning: context)
            }
        }
    }

    private func performAccessibilityQuery() -> SelectedTextContext {
        let systemWide = AXUIElementCreateSystemWide()

        // Get current application name
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"

        // Get focused element
        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success, let element = focusedElement else {
            return SelectedTextContext(
                text: nil,
                isEditable: false,
                isSecure: false,
                applicationName: appName
            )
        }

        let axElement = element as! AXUIElement

        // Check if secure text field (password)
        let isSecure = checkIfSecureTextField(axElement)
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

        // Get selected text
        let selectedText = readSelectedText(from: axElement)

        return SelectedTextContext(
            text: selectedText,
            isEditable: isEditable,
            isSecure: false,
            applicationName: appName
        )
    }

    /// Get selected text by sending Cmd+C and reading from clipboard.
    /// This is a workaround for apps that don't support Accessibility API (e.g., Chrome).
    /// Note: This temporarily modifies the clipboard but restores the original content.
    private func getSelectedTextViaClipboard() -> String? {
        let pasteboard = NSPasteboard.general

        // Save original clipboard content (as string for comparison)
        let originalString = pasteboard.string(forType: .string)

        // Send Cmd+C using session event tap
        // This is more reliable for targeting the frontmost application
        let source = CGEventSource(stateID: .hidSystemState)
        let keyC: CGKeyCode = 0x08  // 'c' key

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: false) else {
            return nil
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        // Use annotated session event tap which targets the frontmost application
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)

        // Poll clipboard for change (more reliable than fixed delay)
        var selectedText: String?
        for _ in 0..<20 {  // Max 400ms wait
            Thread.sleep(forTimeInterval: 0.02)
            let current = pasteboard.string(forType: .string)
            if current != originalString {
                selectedText = current
                break
            }
        }

        if selectedText == nil {
            selectedText = pasteboard.string(forType: .string)
        }

        // Restore original clipboard content
        if let original = originalString {
            pasteboard.clearContents()
            pasteboard.setString(original, forType: .string)
        } else {
            pasteboard.clearContents()
        }

        return selectedText
    }

    private func readSelectedText(from element: AXUIElement) -> String? {
        // Try kAXSelectedTextAttribute first (simpler, more reliable)
        if let text = readSelectedTextAttribute(from: element) {
            return text
        }

        // Fall back to kAXValueAttribute + kAXSelectedTextRangeAttribute
        if let text = readValueWithSelectedRange(from: element) {
            return text
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

        guard selectedResult == .success,
              let text = selectedValue as? String else {
            return nil
        }

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
