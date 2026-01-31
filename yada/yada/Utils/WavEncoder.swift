import Foundation

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
