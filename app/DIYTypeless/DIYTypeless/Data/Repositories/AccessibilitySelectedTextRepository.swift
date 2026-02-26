import AppKit

/// Repository implementation that retrieves selected text using macOS Accessibility API.
///
/// Thread Safety:
/// - Accessibility API calls run on background threads via `withCheckedContinuation`
/// - Clipboard operations run on MainActor as NSPasteboard requires main thread access
///
/// @unchecked Sendable is safe because:
/// - No mutable instance state
/// - NSPasteboard.general and AXUIElement APIs handle their own thread safety
/// - @MainActor methods are explicitly isolated
final class AccessibilitySelectedTextRepository: SelectedTextRepository, @unchecked Sendable {
    func getSelectedText() async -> SelectedTextContext {
        // Step 1: Accessibility API query on background thread
        var context = await performAccessibilityQueryAsync()

        // Step 2: If no selection, try clipboard method on MainActor (for browsers like Chrome)
        if !context.hasSelection {
            if let clipboardText = await getSelectedTextViaClipboardAsync(),
               !clipboardText.isEmpty {
                context = SelectedTextContext(
                    text: clipboardText,
                    isEditable: context.isEditable,
                    isSecure: context.isSecure,
                    applicationName: context.applicationName
                )
            }
        }

        return context
    }

    // MARK: - Accessibility API

    /// Wraps synchronous Accessibility API calls in async continuation.
    /// Runs on background thread to avoid blocking MainActor.
    private func performAccessibilityQueryAsync() async -> SelectedTextContext {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let result = performAccessibilityQuery()
                continuation.resume(returning: result)
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

    // MARK: - Clipboard Method

    /// Configuration for clipboard polling operations.
    private enum ClipboardPollingConfig {
        /// Initial delay after clearing clipboard (ensures clear completes)
        static let initialClearDelay: Duration = .milliseconds(20)

        /// Polling interval between clipboard checks
        static let pollInterval: Duration = .milliseconds(15)

        /// Maximum polling attempts before timeout (50 * 15ms = 750ms max wait)
        static let maxPollAttempts = 50

        /// Delay before restoring clipboard
        static let restoreDelay: Duration = .milliseconds(10)
    }

    /// Get selected text by sending Cmd+C and reading from clipboard.
    /// This is a workaround for apps that don't support Accessibility API (e.g., Chrome).
    /// Note: This temporarily modifies the clipboard but restores the original content.
    ///
    /// Must run on MainActor as NSPasteboard requires main thread access.
    @MainActor
    private func getSelectedTextViaClipboardAsync() async -> String? {
        let pasteboard = NSPasteboard.general

        // Save original clipboard state
        let originalString = pasteboard.string(forType: .string)
        let originalChangeCount = pasteboard.changeCount

        // Clear clipboard
        pasteboard.clearContents()

        // Brief delay to ensure clear completes
        try? await Task.sleep(for: ClipboardPollingConfig.initialClearDelay)

        // Send Cmd+C
        sendCopyCommand()

        // Poll for clipboard change using changeCount (more efficient than reading content)
        for _ in 0..<ClipboardPollingConfig.maxPollAttempts {
            try? await Task.sleep(for: ClipboardPollingConfig.pollInterval)

            // Check if clipboard content changed
            if pasteboard.changeCount != originalChangeCount {
                if let text = pasteboard.string(forType: .string), !text.isEmpty {
                    // Restore original clipboard before returning
                    await restoreClipboard(originalString)
                    return text
                }
            }
        }

        // Timeout - restore original clipboard
        await restoreClipboard(originalString)
        return nil
    }

    @MainActor
    private func sendCopyCommand() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyC: CGKeyCode = 0x08  // 'c' key

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }

    @MainActor
    private func restoreClipboard(_ original: String?) async {
        // Brief delay to ensure any pending reads complete
        try? await Task.sleep(for: ClipboardPollingConfig.restoreDelay)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let original = original {
            pasteboard.setString(original, forType: .string)
        }
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
        guard let valueType = AXValueType(rawValue: kAXValueCFRangeType) else {
            return nil
        }
        AXValueGetValue(rangeRef as! AXValue, valueType, &range)

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
