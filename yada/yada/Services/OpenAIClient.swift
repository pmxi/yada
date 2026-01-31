import Foundation

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
