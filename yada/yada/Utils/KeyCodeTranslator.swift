import Carbon.HIToolbox
import Foundation

enum KeyCodeTranslator {
    static func string(for keyCode: UInt32) -> String {
        if let special = specialKeyName(keyCode) {
            return special
        }
        if let translated = translateKeyCode(keyCode) {
            if translated.count == 1 {
                return translated.uppercased()
            }
            return translated
        }
        return "Key \(keyCode)"
    }

    private static func specialKeyName(_ keyCode: UInt32) -> String? {
        switch keyCode {
        case UInt32(kVK_Space):
            return "Space"
        case UInt32(kVK_Return):
            return "Return"
        case UInt32(kVK_Tab):
            return "Tab"
        case UInt32(kVK_Delete):
            return "⌫"
        case UInt32(kVK_ForwardDelete):
            return "⌦"
        case UInt32(kVK_Escape):
            return "Esc"
        case UInt32(kVK_LeftArrow):
            return "←"
        case UInt32(kVK_RightArrow):
            return "→"
        case UInt32(kVK_UpArrow):
            return "↑"
        case UInt32(kVK_DownArrow):
            return "↓"
        case UInt32(kVK_ANSI_Grave):
            return "`"
        default:
            return nil
        }
    }

    private static func translateKeyCode(_ keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return nil
        }
        guard let layoutDataPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = unsafeBitCast(layoutDataPointer, to: CFData.self)
        guard let keyLayoutPointer = CFDataGetBytePtr(data) else {
            return nil
        }
        let keyLayout = UnsafePointer<UCKeyboardLayout>(OpaquePointer(keyLayoutPointer))

        var deadKeyState: UInt32 = 0
        var length: Int = 0
        var chars = [UniChar](repeating: 0, count: 4)

        let status = UCKeyTranslate(keyLayout,
                                    UInt16(keyCode),
                                    UInt16(kUCKeyActionDisplay),
                                    0,
                                    UInt32(LMGetKbdType()),
                                    UInt32(kUCKeyTranslateNoDeadKeysBit),
                                    &deadKeyState,
                                    chars.count,
                                    &length,
                                    &chars)
        if status != noErr {
            return nil
        }
        if length == 0 {
            return nil
        }
        return String(utf16CodeUnits: chars, count: length)
    }
}
