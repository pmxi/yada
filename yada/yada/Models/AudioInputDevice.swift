import CoreAudio

struct AudioInputDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let deviceID: AudioDeviceID
    let uid: String
}
