//
//  ContentView.swift
//  yada
//
//  Created by Paras Mittal on 2026-01-31.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var viewModel = AppViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Circle()
                    .fill(viewModel.status.color)
                    .frame(width: 10, height: 10)
                Text(viewModel.status.displayText)
                    .font(.headline)
                Spacer()
                Button("Refresh Mics") {
                    viewModel.refreshDevices()
                }
            }
            if !viewModel.statusDetail.isEmpty {
                Text(viewModel.statusDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GroupBox("API Key") {
                HStack {
                    SecureField("OpenAI API Key", text: $viewModel.apiKey)
                    Button("Save") {
                        viewModel.saveApiKey()
                    }
                }
            }

            GroupBox("Microphone") {
                Picker("Input", selection: $viewModel.selectedInputDeviceUID) {
                    ForEach(viewModel.availableInputDevices) { device in
                        Text(device.name).tag(device.id)
                    }
                }
                .onChange(of: viewModel.selectedInputDeviceUID) { _, newValue in
                    viewModel.selectInputDevice(uid: newValue)
                }
                .pickerStyle(.menu)
            }

            HStack {
                Button(viewModel.status == .recording ? "Stop" : "Start") {
                    viewModel.toggleRecording()
                }
                .keyboardShortcut(.space, modifiers: [.command, .shift])
                .disabled(viewModel.status == .transcribing || viewModel.status == .rewriting || viewModel.status == .inserting)

                Spacer()

                Button("Accessibility Settings") {
                    Permissions.openAccessibilitySettings()
                }
                Button("Microphone Settings") {
                    Permissions.openMicrophoneSettings()
                }
            }

            Text("Audio and text are processed in memory only. Nothing is stored on disk.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(minWidth: 420)
        .alert(item: $viewModel.alert) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK")))
        }
    }
}
