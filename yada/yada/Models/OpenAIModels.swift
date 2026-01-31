import Foundation

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
