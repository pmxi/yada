import SwiftUI

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
