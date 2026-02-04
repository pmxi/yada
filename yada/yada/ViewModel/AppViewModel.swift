import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    static let shared = AppViewModel()

    @Published var status: AppStatus = .idle
    @Published var statusDetail: String = ""
    @Published var apiKey: String = ""
    @Published var availableInputDevices: [AudioInputDevice] = []
    @Published var selectedInputDeviceUID: String = ""
    @Published var hotKey: HotKey = .default
    @Published var hotKeyMode: HotKeyMode = .toggle
    @Published var rewritePrompt: String = SettingsStore.defaultRewritePrompt
    @Published var alert: AlertItem?

    private let audioCapture = AudioCapture()
    private let keychain = KeychainStore()
    private var settings = SettingsStore()
    private let inserter = TextInserter()
    private lazy var openAI = OpenAIClient(apiKeyProvider: { [weak self] in
        self?.apiKey
    })

    func load() {
        apiKey = keychain.loadApiKey() ?? ""
        availableInputDevices = AudioDeviceManager.inputDevices()
        if let stored = settings.selectedInputDeviceUID {
            selectedInputDeviceUID = stored
        } else {
            selectedInputDeviceUID = availableInputDevices.first?.id ?? ""
        }

        let keyCode = settings.hotKeyKeyCode ?? HotKey.default.keyCode
        let modifiers = settings.hotKeyModifiers ?? HotKey.default.modifiers
        hotKey = HotKey(keyCode: keyCode, modifiers: modifiers)
        hotKeyMode = settings.hotKeyMode
        rewritePrompt = settings.rewritePrompt
        registerHotKey()
        AudioDeviceManager.startMonitoringDeviceChanges { [weak self] in
            Task { @MainActor in
                self?.refreshDevices()
            }
        }
    }

    func refreshDevices() {
        availableInputDevices = AudioDeviceManager.inputDevices()
        if !availableInputDevices.contains(where: { $0.id == selectedInputDeviceUID }) {
            selectedInputDeviceUID = availableInputDevices.first?.id ?? ""
        }
    }

    func saveApiKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            keychain.deleteApiKey()
            return
        }
        if trimmed != apiKey {
            apiKey = trimmed
        }
        keychain.saveApiKey(trimmed)
    }

    func toggleRecording() {
        switch status {
        case .idle, .error:
            Task { await startRecording() }
        case .recording:
            Task { await stopAndProcess() }
        default:
            return
        }
    }

    func startRecordingIfIdle() {
        guard status == .idle || status == .error else { return }
        Task { await startRecording() }
    }

    func stopRecordingIfRecording() {
        guard status == .recording else { return }
        Task { await stopAndProcess() }
    }

    func selectInputDevice(uid: String) {
        selectedInputDeviceUID = uid
        settings.selectedInputDeviceUID = uid
        if !AudioDeviceManager.setDefaultInputDevice(uid: uid) {
            alert = AlertItem(title: "Microphone Selection", message: "Unable to set the selected microphone as the system default.")
        }
    }

    func updateHotKey(_ newHotKey: HotKey) {
        hotKey = newHotKey
        settings.hotKeyKeyCode = newHotKey.keyCode
        settings.hotKeyModifiers = newHotKey.modifiers
        registerHotKey()
    }

    func updateHotKeyMode(_ mode: HotKeyMode) {
        hotKeyMode = mode
        settings.hotKeyMode = mode
        registerHotKey()
    }

    func saveRewritePrompt() {
        settings.rewritePrompt = rewritePrompt
    }

    func resetRewritePrompt() {
        rewritePrompt = SettingsStore.defaultRewritePrompt
        settings.rewritePrompt = rewritePrompt
    }

    func registerHotKey() {
        switch hotKeyMode {
        case .toggle:
            HotKeyManager.shared.register(keyCode: hotKey.keyCode, modifiers: hotKey.modifiers,
                                          onPress: { [weak self] in self?.toggleRecording() })
        case .hold:
            HotKeyManager.shared.register(keyCode: hotKey.keyCode, modifiers: hotKey.modifiers,
                                          onPress: { [weak self] in self?.startRecordingIfIdle() },
                                          onRelease: { [weak self] in self?.stopRecordingIfRecording() })
        }
    }

    private func startRecording() async {
        guard await Permissions.requestMicrophoneAccess() else {
            setError(title: "Microphone Access", message: "Microphone permission is required.")
            return
        }
        if !Permissions.requestAccessibilityTrust() {
            setError(title: "Accessibility Access", message: "Accessibility permission is required to insert text at the cursor.")
            return
        }
        if !selectedInputDeviceUID.isEmpty {
            if !AudioDeviceManager.setDefaultInputDevice(uid: selectedInputDeviceUID) {
                setError(title: "Microphone Selection", message: "Unable to set the selected microphone as the system default.")
                return
            }
        }
        do {
            try audioCapture.start()
            status = .recording
            statusDetail = "Listening..."
        } catch {
            setError(title: "Audio Error", message: "Failed to start recording: \(error.localizedDescription)")
        }
    }

    private func stopAndProcess() async {
        let captured = audioCapture.stop()
        guard !captured.pcmData.isEmpty else {
            setError(title: "Audio Error", message: "No audio captured.")
            return
        }
        let storedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !storedKey.isEmpty else {
            setError(title: "API Key", message: "OpenAI API key is missing.")
            return
        }

        do {
            status = .transcribing
            statusDetail = "Transcribing..."
            let wavData = WavEncoder.encode(pcmData: captured.pcmData,
                                            sampleRate: captured.sampleRate,
                                            channels: captured.channels,
                                            bitsPerSample: captured.bitsPerSample)
            let transcript = try await openAI.transcribe(audioWavData: wavData)

            status = .rewriting
            statusDetail = "Rewriting..."
            let rewritten = try await openAI.rewrite(text: transcript, instructions: rewritePrompt)

            status = .inserting
            statusDetail = "Inserting..."
            let inserted = inserter.insert(text: rewritten)
            if !inserted {
                setError(title: "Insert Failed", message: "Could not insert text at the cursor.")
                return
            }

            status = .idle
            statusDetail = ""
        } catch {
            setError(title: "OpenAI", message: error.localizedDescription)
        }
    }

    private func setError(title: String, message: String) {
        status = .error
        statusDetail = ""
        alert = AlertItem(title: title, message: message)
    }
}
