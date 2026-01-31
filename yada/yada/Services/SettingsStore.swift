import Foundation

struct SettingsStore {
    private let selectedDeviceKey = "selectedInputDeviceUID"

    var selectedInputDeviceUID: String? {
        get { UserDefaults.standard.string(forKey: selectedDeviceKey) }
        set { UserDefaults.standard.setValue(newValue, forKey: selectedDeviceKey) }
    }
}
