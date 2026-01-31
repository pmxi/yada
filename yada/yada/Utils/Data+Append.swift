import Foundation

extension Data {
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
