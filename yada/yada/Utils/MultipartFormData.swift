import Foundation

struct MultipartFormData {
    private let boundary = "Boundary-\(UUID().uuidString)"
    private var bodyData = Data()

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    var body: Data {
        var data = bodyData
        data.append("--\(boundary)--\r\n")
        return data
    }

    mutating func addField(name: String, value: String) {
        bodyData.append("--\(boundary)\r\n")
        bodyData.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        bodyData.append("\(value)\r\n")
    }

    mutating func addFile(name: String, filename: String, mimeType: String, data: Data) {
        bodyData.append("--\(boundary)\r\n")
        bodyData.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        bodyData.append("Content-Type: \(mimeType)\r\n\r\n")
        bodyData.append(data)
        bodyData.append("\r\n")
    }
}
