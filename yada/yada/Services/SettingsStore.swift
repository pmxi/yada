import Foundation

struct SettingsStore {
    private let selectedDeviceKey = "selectedInputDeviceUID"
    private let hotKeyCodeKey = "hotKeyKeyCode"
    private let hotKeyModifiersKey = "hotKeyModifiers"

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
}
