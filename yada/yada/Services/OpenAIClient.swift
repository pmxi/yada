import Foundation
#if DEBUG
import os
#endif

#if DEBUG
private struct DebugRequestToken {
    let directory: URL
    let prefix: String
}

private enum DebugNetworkLogger {
    private static let logger = Logger(subsystem: "dev.yada", category: "OpenAIDebug")
    private static let logEnvKey = "YADA_OPENAI_DEBUG"
    private static let logAuthEnvKey = "YADA_OPENAI_DEBUG_AUTH"

    static func logRequest(_ request: URLRequest, body: Data?, label: String) -> DebugRequestToken? {
        guard isEnabled else { return nil }
        let directory = logDirectory()
        let prefix = "\(timestamp())-\(label)-\(UUID().uuidString)"
        let metaURL = directory.appendingPathComponent("\(prefix)-request.txt")
        let bodyURL = directory.appendingPathComponent("\(prefix)-request.body")

        var lines: [String] = []
        lines.append("Time: \(isoTimestamp())")
        if let method = request.httpMethod {
            lines.append("Method: \(method)")
        }
        if let url = request.url?.absoluteString {
            lines.append("URL: \(url)")
        }
        lines.append("Headers:")
        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            let outputValue = shouldRedactHeader(key) ? "REDACTED" : value
            lines.append("  \(key): \(outputValue)")
        }
        let bodyLength = body?.count ?? 0
        lines.append("Body-Length: \(bodyLength)")
        if let body, let bodyText = String(data: body, encoding: .utf8) {
            lines.append("Body-UTF8:")
            lines.append(bodyText)
        }
        writeText(lines.joined(separator: "\n"), to: metaURL)
        if let body {
            writeData(body, to: bodyURL)
        }
        logger.debug("OpenAI request logged to \(metaURL.path, privacy: .public)")
        return DebugRequestToken(directory: directory, prefix: prefix)
    }

    static func logResponse(_ token: DebugRequestToken?, response: URLResponse, data: Data) {
        guard let token else { return }
        let metaURL = token.directory.appendingPathComponent("\(token.prefix)-response.txt")
        let bodyURL = token.directory.appendingPathComponent("\(token.prefix)-response.body")

        var lines: [String] = []
        lines.append("Time: \(isoTimestamp())")
        if let http = response as? HTTPURLResponse {
            lines.append("Status: \(http.statusCode)")
            lines.append("Headers:")
            for (key, value) in http.allHeaderFields {
                lines.append("  \(key): \(value)")
            }
        } else {
            lines.append("Status: (non-HTTP response)")
        }
        lines.append("Body-Length: \(data.count)")
        if let bodyText = String(data: data, encoding: .utf8) {
            lines.append("Body-UTF8:")
            lines.append(bodyText)
        }
        writeText(lines.joined(separator: "\n"), to: metaURL)
        writeData(data, to: bodyURL)
        logger.debug("OpenAI response logged to \(metaURL.path, privacy: .public)")
    }

    private static var isEnabled: Bool {
        isTruthy(ProcessInfo.processInfo.environment[logEnvKey])
    }

    private static var includeAuthHeader: Bool {
        isTruthy(ProcessInfo.processInfo.environment[logAuthEnvKey])
    }

    private static func shouldRedactHeader(_ key: String) -> Bool {
        key.caseInsensitiveCompare("Authorization") == .orderedSame && !includeAuthHeader
    }

    private static func isTruthy(_ value: String?) -> Bool {
        guard let value else { return false }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "1" || normalized == "true" || normalized == "yes"
    }

    private static func logDirectory() -> URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
        let base = library ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("Logs/yada-debug", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter.string(from: Date())
    }

    private static func isoTimestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func writeText(_ text: String, to url: URL) {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            logger.error("Failed writing debug log text: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func writeData(_ data: Data, to url: URL) {
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("Failed writing debug log data: \(error.localizedDescription, privacy: .public)")
        }
    }
}
#else
private struct DebugRequestToken {}
private enum DebugNetworkLogger {
    static func logRequest(_ request: URLRequest, body: Data?, label: String) -> DebugRequestToken? { nil }
    static func logResponse(_ token: DebugRequestToken?, response: URLResponse, data: Data) {}
}
#endif

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

        let debugToken = DebugNetworkLogger.logRequest(request, body: request.httpBody, label: "transcribe")
        let (data, response) = try await session.data(for: request)
        DebugNetworkLogger.logResponse(debugToken, response: response, data: data)
        try validateResponse(response, data: data)
        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return decoded.text
    }

    func rewrite(text: String, instructions: String) async throws -> String {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw ClientError.missingApiKey
        }

        let payload = ResponsesRequest(
            model: "gpt-5-mini",
            input: text,
            instructions: instructions,
            reasoning: .init(effort: "minimal")
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let debugToken = DebugNetworkLogger.logRequest(request, body: request.httpBody, label: "rewrite")
        let (data, response) = try await session.data(for: request)
        DebugNetworkLogger.logResponse(debugToken, response: response, data: data)
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
