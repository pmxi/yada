import Foundation

struct CapturedAudio {
    let pcmData: Data
    let sampleRate: Int
    let channels: Int
    let bitsPerSample: Int
}
