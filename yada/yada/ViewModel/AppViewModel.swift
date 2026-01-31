import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    static let shared = AppViewModel()

    @Published var status: AppStatus = .idle
    @Published var statusDetail: String = ""
    @Published var apiKey: String = ""
    @Published var availableInputDevices: [AudioInputDevice] = []
    @Published var selectedInputDeviceUID: String = ""
    @Published var alert: AlertItem?

    private let audioCapture = AudioCapture()
    private let keychain = KeychainStore()
    private var settings = SettingsStore()
    private let inserter = TextInserter()
    private lazy var openAI = OpenAIClient(apiKeyProvider: { [keychain] in
        keychain.loadApiKey()
    })

    func load() {
        apiKey = keychain.loadApiKey() ?? ""
        availableInputDevices = AudioDeviceManager.inputDevices()
        if let stored = settings.selectedInputDeviceUID {
            selectedInputDeviceUID = stored
        } else {
            selectedInputDeviceUID = availableInputDevices.first?.id ?? ""
        }
    }

    func refreshDevices() {
        availableInputDevices = AudioDeviceManager.inputDevices()
        if !availableInputDevices.contains(where: { $0.id == selectedInputDeviceUID }) {
            selectedInputDeviceUID = availableInputDevices.first?.id ?? ""
        }
    }

    func saveApiKey() {
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            keychain.deleteApiKey()
            return
        }
        keychain.saveApiKey(apiKey)
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

    func selectInputDevice(uid: String) {
        selectedInputDeviceUID = uid
        settings.selectedInputDeviceUID = uid
        if !AudioDeviceManager.setDefaultInputDevice(uid: uid) {
            alert = AlertItem(title: "Microphone Selection", message: "Unable to set the selected microphone as the system default.")
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
        guard let storedKey = keychain.loadApiKey(), !storedKey.isEmpty else {
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
            let rewritten = try await openAI.rewrite(text: transcript)

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
