import AppKit

enum OutputResult: Equatable {
    case pasted
    case copied
}

final class TextOutputManager {
    func deliver(text: String) -> OutputResult {
        copyToClipboard(text)
        if let element = focusedTextElement(), isEditableTextElement(element) {
            if sendPasteCommand() {
                return .pasted
            }
        }
        return .copied
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func focusedTextElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        )
        guard result == .success, let element = focused else {
            return nil
        }
        return (element as! AXUIElement)
    }

    private func isEditableTextElement(_ element: AXUIElement) -> Bool {
        var roleValue: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &roleValue
        )
        guard roleResult == .success, let role = roleValue as? String else {
            return false
        }

        let allowedRoles = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            "AXSearchField",
            kAXComboBoxRole as String
        ]

        guard allowedRoles.contains(role) else {
            return false
        }

        var editableValue: CFTypeRef?
        let editableResult = AXUIElementCopyAttributeValue(
            element,
            "AXEditable" as CFString,
            &editableValue
        )
        if editableResult == .success, let isEditable = editableValue as? Bool {
            return isEditable
        }
        return true
    }

    private func sendPasteCommand() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            return false
        }

        let keyV: CGKeyCode = 0x09
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}

