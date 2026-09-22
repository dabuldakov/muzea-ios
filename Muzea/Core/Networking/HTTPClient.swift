import Foundation

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) { append(data) }
    }
}

struct MultipartFile {
    let field: String
    let fileName: String
    let mimeType: String
    let data: Data
}

final class HTTPClient {
    let baseURL: URL
    private let session: URLSession
    private let tokenProvider: () -> String?

    init(baseURL: URL, tokenProvider: @escaping () -> String?) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Public API

    func request<T: Decodable>(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Encodable? = nil,
        authorized: Bool = true
    ) async throws -> T {
        let data = try await perform(method, path, query: query, body: body, authorized: authorized)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    func requestVoid(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Encodable? = nil,
        authorized: Bool = true
    ) async throws {
        _ = try await perform(method, path, query: query, body: body, authorized: authorized)
    }

    func requestData(
        _ method: String,
        _ path: String,
        authorized: Bool = true
    ) async throws -> Data {
        try await perform(method, path, query: [], body: nil, authorized: authorized)
    }

    func upload<T: Decodable>(
        _ path: String,
        method: String = "POST",
        fields: [String: String] = [:],
        files: [MultipartFile],
        authorized: Bool = true
    ) async throws -> T {
        let data = try await uploadData(
            path,
            method: method,
            fields: fields,
            files: files,
            authorized: authorized
        )
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// multipart/form-data с файлами, возвращает сырое тело ответа (без JSON-разбора).
    @discardableResult
    func uploadData(
        _ path: String,
        method: String = "POST",
        fields: [String: String] = [:],
        files: [MultipartFile],
        authorized: Bool = true
    ) async throws -> Data {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: try makeURL(path, query: []))
        request.httpMethod = method
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if authorized, let token = tokenProvider(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = multipartBody(boundary: boundary, fields: fields, files: files)
        return try await execute(request)
    }

    /// multipart/form-data только из текстовых полей (без файла).
    func uploadForm<T: Decodable>(
        _ path: String,
        method: String = "POST",
        fields: [String: String],
        authorized: Bool = true
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: try makeURL(path, query: []))
        request.httpMethod = method
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if authorized, let token = tokenProvider(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = multipartFieldsBody(boundary: boundary, fields: fields)

        let data = try await execute(request)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    // MARK: - Internals

    private func perform(
        _ method: String,
        _ path: String,
        query: [URLQueryItem],
        body: Encodable?,
        authorized: Bool
    ) async throws -> Data {
        var request = URLRequest(url: try makeURL(path, query: query))
        request.httpMethod = method
        if let body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authorized, let token = tokenProvider(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await execute(request)
    }

    private func execute(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.server(-1, "Пустой ответ")
            }
            switch http.statusCode {
            case 200..<300:
                return data
            case 401:
                throw APIError.unauthorized
            default:
                let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                throw APIError.server(http.statusCode, message)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error)
        }
    }

    private func makeURL(_ path: String, query: [URLQueryItem]) throws -> URL {
        let baseString = baseURL.absoluteString.hasSuffix("/")
            ? String(baseURL.absoluteString.dropLast())
            : baseURL.absoluteString
        let suffix = path.hasPrefix("/") ? path : "/" + path
        guard var components = URLComponents(string: baseString + suffix) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }

    private func multipartBody(
        boundary: String,
        fields: [String: String],
        files: [MultipartFile]
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        for (key, value) in fields {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak)\(lineBreak)")
            body.append("\(value)\(lineBreak)")
        }
        for file in files {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(file.field)\"; filename=\"\(file.fileName)\"\(lineBreak)")
            body.append("Content-Type: \(file.mimeType)\(lineBreak)\(lineBreak)")
            body.append(file.data)
            body.append(lineBreak)
        }
        body.append("--\(boundary)--\(lineBreak)")
        return body
    }

    private func multipartFieldsBody(boundary: String, fields: [String: String]) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        for (key, value) in fields {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak)\(lineBreak)")
            body.append("\(value)\(lineBreak)")
        }
        body.append("--\(boundary)--\(lineBreak)")
        return body
    }
}
