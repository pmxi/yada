//
//  yadaApp.swift
//  yada
//
//  Created by Paras Mittal on 2026-01-31.
//

import SwiftUI

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
