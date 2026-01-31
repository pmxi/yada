import AVFoundation

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
