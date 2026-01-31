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
        let setResult = AXUIElementSetAttributeValue(axElement,
                                                     kAXValueAttribute as CFString,
                                                     text as CFTypeRef)
        return setResult == .success
    }

    private func pasteViaClipboard(text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let savedItems = pasteboard.pasteboardItems ?? []
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        sendPasteShortcut()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            pasteboard.clearContents()
            pasteboard.writeObjects(savedItems)
        }
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
