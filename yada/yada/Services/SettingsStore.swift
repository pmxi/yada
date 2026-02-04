import Foundation

struct SettingsStore {
    private let selectedDeviceKey = "selectedInputDeviceUID"
    private let hotKeyCodeKey = "hotKeyKeyCode"
    private let hotKeyModifiersKey = "hotKeyModifiers"
    private let hotKeyModeKey = "hotKeyMode"
    private let rewritePromptKey = "rewritePrompt"

    static let defaultRewritePrompt = "Rewrite the text with correct punctuation and capitalization. Preserve meaning. Return plain text only."

    var selectedInputDeviceUID: String? {
        get { UserDefaults.standard.string(forKey: selectedDeviceKey) }
        set { UserDefaults.standard.setValue(newValue, forKey: selectedDeviceKey) }
    }

    var hotKeyKeyCode: UInt32? {
        get {
            guard let value = UserDefaults.standard.object(forKey: hotKeyCodeKey) as? Int else {
                return nil
            }
            return UInt32(value)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(Int(newValue), forKey: hotKeyCodeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: hotKeyCodeKey)
            }
        }
    }

    var hotKeyModifiers: UInt32? {
        get {
            guard let value = UserDefaults.standard.object(forKey: hotKeyModifiersKey) as? Int else {
                return nil
            }
            return UInt32(value)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(Int(newValue), forKey: hotKeyModifiersKey)
            } else {
                UserDefaults.standard.removeObject(forKey: hotKeyModifiersKey)
            }
        }
    }

    var hotKeyMode: HotKeyMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: hotKeyModeKey),
                  let mode = HotKeyMode(rawValue: raw) else { return .toggle }
            return mode
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: hotKeyModeKey) }
    }

    var rewritePrompt: String {
        get { UserDefaults.standard.string(forKey: rewritePromptKey) ?? Self.defaultRewritePrompt }
        set {
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                UserDefaults.standard.removeObject(forKey: rewritePromptKey)
            } else {
                UserDefaults.standard.set(newValue, forKey: rewritePromptKey)
            }
        }
    }
}
