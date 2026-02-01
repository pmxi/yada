import AppKit
import Carbon.HIToolbox

struct HotKey: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let `default` = HotKey(keyCode: UInt32(kVK_ANSI_Grave), modifiers: UInt32(cmdKey))

    var displayString: String {
        modifierSymbols + KeyCodeTranslator.string(for: keyCode)
    }

    private var modifierSymbols: String {
        var symbols = ""
        if modifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var value: UInt32 = 0
        if flags.contains(.control) { value |= UInt32(controlKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }
        if flags.contains(.shift) { value |= UInt32(shiftKey) }
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        return value
    }

    static func isModifierKeyCode(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case UInt16(kVK_Command), UInt16(kVK_RightCommand),
             UInt16(kVK_Shift), UInt16(kVK_RightShift),
             UInt16(kVK_Option), UInt16(kVK_RightOption),
             UInt16(kVK_Control), UInt16(kVK_RightControl):
            return true
        default:
            return false
        }
    }
}
