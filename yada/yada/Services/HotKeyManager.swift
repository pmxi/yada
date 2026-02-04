import Foundation
import Carbon.HIToolbox

final class HotKeyManager {
    static let shared = HotKeyManager()

    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var pressAction: (() -> Void)?
    private var releaseAction: (() -> Void)?

    private init() {}

    func register(keyCode: UInt32, modifiers: UInt32,
                  onPress: @escaping () -> Void,
                  onRelease: (() -> Void)? = nil) {
        unregister()
        self.pressAction = onPress
        self.releaseAction = onRelease

        var eventSpecs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData, let event else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            let eventKind = Int(GetEventKind(event))
            if eventKind == kEventHotKeyPressed {
                manager.triggerPress()
            } else if eventKind == kEventHotKeyReleased {
                manager.triggerRelease()
            }
            return noErr
        }, 2, &eventSpecs, selfPtr, &eventHandler)

        let signature = OSType(0x59414441) // 'YADA'
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        pressAction = nil
        releaseAction = nil
    }

    private func triggerPress() {
        guard let pressAction else { return }
        Task { @MainActor in
            pressAction()
        }
    }

    private func triggerRelease() {
        guard let releaseAction else { return }
        Task { @MainActor in
            releaseAction()
        }
    }
}
