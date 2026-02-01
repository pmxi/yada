import AppKit
import ApplicationServices

final class TextInserter {
    func insert(text: String) -> Bool {
        if tryAccessibilityInsert(text: text) {
            return true
        }
        return pasteViaClipboard(text: text)
    }

    private func tryAccessibilityInsert(text: String) -> Bool {
        let systemElement = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemElement,
                                                  kAXFocusedUIElementAttribute as CFString,
                                                  &focused)
        guard result == .success, let element = focused else {
            return false
        }
        let axElement = unsafeBitCast(element, to: AXUIElement.self)
        if setSelectedTextIfPossible(element: axElement, text: text) {
            return true
        }
        guard shouldUseValueInsert(for: axElement) else {
            return false
        }
        let setResult = AXUIElementSetAttributeValue(axElement,
                                                     kAXValueAttribute as CFString,
                                                     text as CFTypeRef)
        return setResult == .success
    }

    private func setSelectedTextIfPossible(element: AXUIElement, text: String) -> Bool {
        guard isAttributeSettable(element, kAXSelectedTextAttribute as CFString) else {
            return false
        }
        let setResult = AXUIElementSetAttributeValue(element,
                                                     kAXSelectedTextAttribute as CFString,
                                                     text as CFTypeRef)
        return setResult == .success
    }

    private func shouldUseValueInsert(for element: AXUIElement) -> Bool {
        guard isAttributeSettable(element, kAXValueAttribute as CFString) else {
            return false
        }
        if let role = copyStringAttribute(element, kAXRoleAttribute as CFString) {
            return role == kAXTextFieldRole as String
        }
        return true
    }

    private func isAttributeSettable(_ element: AXUIElement, _ attribute: CFString) -> Bool {
        var settable: DarwinBoolean = false
        let result = AXUIElementIsAttributeSettable(element, attribute, &settable)
        return result == .success && settable.boolValue
    }

    private func copyStringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else {
            return nil
        }
        return value as? String
    }

    private func pasteViaClipboard(text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        // TODO: Clipboard restore removed to avoid NSPasteboardItem reuse crash; consider safe restore later.
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        sendPasteShortcut()
        return true
    }

    private func sendPasteShortcut() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let keyV: CGKeyCode = 9
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: keyV, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: keyV, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
