import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppViewModel.shared.load()
        HotKeyManager.shared.register(commandKey: true,
                                      shift: true,
                                      keyCode: UInt32(kVK_Space)) {
            AppViewModel.shared.toggleRecording()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }
}
