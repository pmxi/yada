import CoreAudio

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
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var name: Unmanaged<CFString>?
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &name)
        if status == noErr, let name {
            let value = name.takeUnretainedValue() as String
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
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var uid: Unmanaged<CFString>?
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &uid)
        if status == noErr, let uid {
            let value = uid.takeUnretainedValue() as String
            return value.isEmpty ? nil : value
        }
        return nil
    }
}
