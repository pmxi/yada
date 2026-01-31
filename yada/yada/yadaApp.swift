//
//  yadaApp.swift
//  yada
//
//  Created by Paras Mittal on 2026-01-31.
//

import SwiftUI
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

@main
struct yadaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
