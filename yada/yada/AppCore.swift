import SwiftUI
import AVFoundation
import AppKit
import ApplicationServices
import CoreAudio

enum AppStatus: String {
    case idle
    case recording
    case transcribing
    case rewriting
    case inserting
    case error

    var displayText: String {
        switch self {
        case .idle:
            return "Idle"
        case .recording:
            return "Listening"
        case .transcribing:
            return "Transcribing"
        case .rewriting:
            return "Rewriting"
        case .inserting:
            return "Inserting"
        case .error:
            return "Error"
        }
    }

    var color: Color {
        switch self {
        case .idle:
            return .gray
        case .recording:
            return .red
        case .transcribing, .rewriting, .inserting:
            return .orange
        case .error:
            return .red
        }
    }
}

struct AudioInputDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let deviceID: AudioDeviceID
    let uid: String
}

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

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

struct CapturedAudio {
    let pcmData: Data
    let sampleRate: Int
    let channels: Int
    let bitsPerSample: Int
}

final class AudioCapture {
    private let engine = AVAudioEngine()
    private let outputFormat: AVAudioFormat
    private var converter: AVAudioConverter?
    private var pcmData = Data()

    init() {
        outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                     sampleRate: 16_000,
                                     channels: 1,
                                     interleaved: false)!
    }

    func start() throws {
        pcmData.removeAll(keepingCapacity: true)
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.handle(buffer: buffer)
        }
        engine.prepare()
        try engine.start()
    }

    func stop() -> CapturedAudio {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        return CapturedAudio(pcmData: pcmData,
                             sampleRate: Int(outputFormat.sampleRate),
                             channels: Int(outputFormat.channelCount),
                             bitsPerSample: 16)
    }

    private func handle(buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1.0)
        guard let converted = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        converter.convert(to: converted, error: &error, withInputFrom: inputBlock)
        if error != nil { return }
        guard let channelData = converted.int16ChannelData else { return }
        let frames = Int(converted.frameLength)
        let channelCount = Int(outputFormat.channelCount)
        let byteCount = frames * channelCount * MemoryLayout<Int16>.size
        pcmData.append(Data(bytes: channelData[0], count: byteCount))
    }

}

struct AudioDeviceManager {
    static func inputDevices() -> [AudioInputDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let systemObjectID = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(systemObjectID, &address, 0, nil, &dataSize) == noErr else {
            return []
        }
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(systemObjectID, &address, 0, nil, &dataSize, &deviceIDs) == noErr else {
            return []
        }
        var devices: [AudioInputDevice] = []
        for deviceID in deviceIDs {
            guard hasInput(deviceID) else { continue }
            guard let name = deviceName(deviceID), let uid = deviceUID(deviceID) else { continue }
            devices.append(AudioInputDevice(id: uid, name: name, deviceID: deviceID, uid: uid))
        }
        return devices.sorted { $0.name < $1.name }
    }

    static func setDefaultInputDevice(uid: String) -> Bool {
        guard let deviceID = inputDevices().first(where: { $0.uid == uid })?.deviceID else {
            return false
        }
        var mutableID = deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                                &address,
                                                0,
                                                nil,
                                                UInt32(MemoryLayout<AudioDeviceID>.size),
                                                &mutableID)
        return status == noErr
    }

    private static func hasInput(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr else {
            return false
        }
        let rawPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize),
                                                          alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { rawPointer.deallocate() }
        let bufferListPointer = rawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, bufferListPointer) == noErr else {
            return false
        }
        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        return bufferList.contains { $0.mNumberChannels > 0 }
    }

    private static func deviceName(_ deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        var name: CFString = "" as CFString
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &name)
        if status == noErr {
            let value = name as String
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private static func deviceUID(_ deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        var uid: CFString = "" as CFString
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &uid)
        if status == noErr {
            let value = uid as String
            return value.isEmpty ? nil : value
        }
        return nil
    }
}

struct OpenAIClient {
    enum ClientError: LocalizedError {
        case missingApiKey
        case invalidResponse
        case apiError(String)
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .missingApiKey:
                return "OpenAI API key not configured."
            case .invalidResponse:
                return "Unexpected response from OpenAI."
            case .apiError(let message):
                return message
            case .decodingFailed:
                return "Failed to decode response from OpenAI."
            }
        }
    }

    let apiKeyProvider: () -> String?
    let session: URLSession = .shared

    func transcribe(audioWavData: Data) async throws -> String {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw ClientError.missingApiKey
        }

        var form = MultipartFormData()
        form.addField(name: "model", value: "gpt-4o-transcribe")
        form.addFile(name: "file", filename: "audio.wav", mimeType: "audio/wav", data: audioWavData)

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = form.body

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return decoded.text
    }

    func rewrite(text: String) async throws -> String {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw ClientError.missingApiKey
        }

        let payload = ResponsesRequest(
            model: "gpt-5-mini",
            input: text,
            instructions: "Rewrite the text with correct punctuation and capitalization. Preserve meaning. Return plain text only.",
            maxOutputTokens: 512
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        let decoded = try JSONDecoder().decode(ResponsesCreateResponse.self, from: data)
        let text = decoded.outputText
        if text.isEmpty {
            throw ClientError.decodingFailed
        }
        return text
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if let apiError = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw ClientError.apiError(apiError.error.message)
            }
            throw ClientError.apiError("OpenAI error (HTTP \(http.statusCode)).")
        }
    }
}

struct TranscriptionResponse: Decodable {
    let text: String
}

struct OpenAIErrorResponse: Decodable {
    struct OpenAIError: Decodable {
        let message: String
    }
    let error: OpenAIError
}

struct ResponsesRequest: Encodable {
    let model: String
    let input: String
    let instructions: String
    let maxOutputTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case instructions
        case maxOutputTokens = "max_output_tokens"
    }
}

struct ResponsesCreateResponse: Decodable {
    struct OutputItem: Decodable {
        struct ContentItem: Decodable {
            let type: String
            let text: String?
        }
        let type: String
        let content: [ContentItem]?
    }

    let output: [OutputItem]?

    var outputText: String {
        let items = output ?? []
        var collected: [String] = []
        for item in items where item.type == "message" {
            for content in item.content ?? [] where content.type == "output_text" {
                if let text = content.text {
                    collected.append(text)
                }
            }
        }
        return collected.joined()
    }
}

struct Permissions {
    static func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }

    static func requestAccessibilityTrust() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    static func openMicrophoneSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

final class TextInserter {
    func insert(text: String) -> Bool {
        if tryAccessibilityInsert(text: text) {
            return true
        }
        return pasteViaClipboard(text: text)
    }

    private func tryAccessibilityInsert(text: String) -> Bool {
        let systemElement = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemElement,
                                                  kAXFocusedUIElementAttribute as CFString,
                                                  &focused)
        guard result == .success, let element = focused else {
            return false
        }
        let axElement = unsafeBitCast(element, to: AXUIElement.self)
        let setResult = AXUIElementSetAttributeValue(axElement,
                                                     kAXValueAttribute as CFString,
                                                     text as CFTypeRef)
        return setResult == .success
    }

    private func pasteViaClipboard(text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let savedItems = pasteboard.pasteboardItems ?? []
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        sendPasteShortcut()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            pasteboard.clearContents()
            pasteboard.writeObjects(savedItems)
        }
        return true
    }

    private func sendPasteShortcut() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let keyV: CGKeyCode = 9
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: keyV, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: keyV, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

struct KeychainStore {
    private let service = "dev.yada"
    private let account = "openai-api-key"

    func saveApiKey(_ key: String) {
        let data = Data(key.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func loadApiKey() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func deleteApiKey() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

struct SettingsStore {
    private let selectedDeviceKey = "selectedInputDeviceUID"

    var selectedInputDeviceUID: String? {
        get { UserDefaults.standard.string(forKey: selectedDeviceKey) }
        set { UserDefaults.standard.setValue(newValue, forKey: selectedDeviceKey) }
    }
}

struct WavEncoder {
    static func encode(pcmData: Data, sampleRate: Int, channels: Int, bitsPerSample: Int) -> Data {
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = pcmData.count
        let riffSize = 36 + dataSize

        var header = Data()
        header.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
        header.append(uint32LE: UInt32(riffSize))
        header.append(contentsOf: [0x57, 0x41, 0x56, 0x45])
        header.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
        header.append(uint32LE: 16)
        header.append(uint16LE: 1)
        header.append(uint16LE: UInt16(channels))
        header.append(uint32LE: UInt32(sampleRate))
        header.append(uint32LE: UInt32(byteRate))
        header.append(uint16LE: UInt16(blockAlign))
        header.append(uint16LE: UInt16(bitsPerSample))
        header.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
        header.append(uint32LE: UInt32(dataSize))
        header.append(pcmData)
        return header
    }
}

struct MultipartFormData {
    private let boundary = "Boundary-\(UUID().uuidString)"
    private var bodyData = Data()

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    var body: Data {
        var data = bodyData
        data.append("--\(boundary)--\r\n")
        return data
    }

    mutating func addField(name: String, value: String) {
        bodyData.append("--\(boundary)\r\n")
        bodyData.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        bodyData.append("\(value)\r\n")
    }

    mutating func addFile(name: String, filename: String, mimeType: String, data: Data) {
        bodyData.append("--\(boundary)\r\n")
        bodyData.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        bodyData.append("Content-Type: \(mimeType)\r\n\r\n")
        bodyData.append(data)
        bodyData.append("\r\n")
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }

    mutating func append(uint16LE value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    mutating func append(uint32LE value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
