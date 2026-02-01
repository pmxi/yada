import AppKit
import Carbon.HIToolbox
import SwiftUI

struct HotKeyRecorder: View {
    let hotKey: HotKey
    let onChange: (HotKey) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(hotKey.displayString)
                .font(.system(.body, design: .monospaced))
            Spacer()
            Button(isRecording ? "Press keys..." : "Change") {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }
            if HotKey.isModifierKeyCode(event.keyCode) {
                return nil
            }
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if flags.isEmpty {
                return nil
            }
            let modifiers = HotKey.carbonModifiers(from: flags)
            let newHotKey = HotKey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            onChange(newHotKey)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }
}
