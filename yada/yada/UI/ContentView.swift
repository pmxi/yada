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

            GroupBox("Hotkey to record") {
                VStack(alignment: .leading, spacing: 8) {
                    HotKeyRecorder(hotKey: viewModel.hotKey) { newHotKey in
                        viewModel.updateHotKey(newHotKey)
                    }
                    Picker("", selection: $viewModel.hotKeyMode) {
                        ForEach(HotKeyMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .onChange(of: viewModel.hotKeyMode) { _, newValue in
                        viewModel.updateHotKeyMode(newValue)
                    }
                }
            }

            GroupBox("Rewrite Prompt") {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $viewModel.rewritePrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 60, maxHeight: 100)
                    HStack {
                        Button("Save") { viewModel.saveRewritePrompt() }
                        Button("Reset") { viewModel.resetRewritePrompt() }
                        Spacer()
                    }
                    Text("Instructions for GPT to rewrite transcribed text.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button(viewModel.status == .recording ? "Stop" : "Start") {
                    viewModel.toggleRecording()
                }
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
