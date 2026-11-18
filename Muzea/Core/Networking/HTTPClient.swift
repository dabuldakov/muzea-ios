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
    private let pinningDelegate: PinnedSessionDelegate?
    private let tokenProvider: () -> String?

    /// Вызывается при 401 (и при 403, если `treatsForbiddenAsUnauthorized`):
    /// должен обновить токен и вернуть `true`, чтобы запрос повторился один раз.
    /// `failedToken` позволяет не обновлять токен повторно, если его уже
    /// обновил другой параллельный запрос.
    var unauthorizedHandler: ((_ failedToken: String?) async -> Bool)?
    /// makeup отдаёт 403 вместо 401 для невалидного/просроченного токена.
    var treatsForbiddenAsUnauthorized = false

    init(baseURL: URL, tokenProvider: @escaping () -> String?, session: URLSession? = nil) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        if let session {
            self.pinningDelegate = nil
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 300
            // Приватные ответы не должны оседать в дисковом URLCache или куках:
            // у чата/ленты есть собственные кэши, которые чистятся при выходе.
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            let delegate = PinnedSessionDelegate()
            self.pinningDelegate = delegate
            self.session = URLSession(
                configuration: configuration,
                delegate: delegate,
                delegateQueue: nil
            )
        }
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
        authorized: Bool = true,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> T {
        let data = try await uploadData(
            path,
            method: method,
            fields: fields,
            files: files,
            authorized: authorized,
            onProgress: onProgress
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
        authorized: Bool = true,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> Data {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: try makeURL(path, query: []))
        request.httpMethod = method
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if authorized, let token = tokenProvider(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = multipartBody(boundary: boundary, fields: fields, files: files)
        return try await execute(request, onProgress: onProgress)
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

    private func execute(
        _ request: URLRequest,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> Data {
        var current = request
        var attempt = 0

        while true {
            do {
                let (data, response) = try await send(current, onProgress: onProgress)
                guard let http = response as? HTTPURLResponse else {
                    throw APIError.server(-1, L10n.emptyResponse)
                }
                switch http.statusCode {
                case 200..<300:
                    return data

                case 401:
                    if attempt == 0, await refreshIfPossible(sentToken: Self.bearerToken(in: current)) {
                        attempt += 1
                        applyLatestToken(to: &current)
                        continue
                    }
                    throw APIError.unauthorized

                case 403 where treatsForbiddenAsUnauthorized && attempt == 0:
                    if await refreshIfPossible(sentToken: Self.bearerToken(in: current)) {
                        attempt += 1
                        applyLatestToken(to: &current)
                        continue
                    }
                    let message = String(data: data, encoding: .utf8) ?? "HTTP 403"
                    throw APIError.server(403, message)

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
    }

    /// Обычный запрос или запрос с отчётом о прогрессе отправки тела.
    private func send(
        _ request: URLRequest,
        onProgress: ((Double) -> Void)?
    ) async throws -> (Data, URLResponse) {
        guard let onProgress else {
            return try await session.data(for: request)
        }
        let delegate = UploadProgressDelegate(handler: onProgress)
        return try await session.data(for: request, delegate: delegate)
    }

    private func refreshIfPossible(sentToken: String?) async -> Bool {
        guard let handler = unauthorizedHandler else { return false }
        return await handler(sentToken)
    }

    private func applyLatestToken(to request: inout URLRequest) {
        if let token = tokenProvider(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue(nil, forHTTPHeaderField: "Authorization")
        }
    }

    private static func bearerToken(in request: URLRequest) -> String? {
        guard let value = request.value(forHTTPHeaderField: "Authorization") else { return nil }
        let prefix = "Bearer "
        return value.hasPrefix(prefix) ? String(value.dropFirst(prefix.count)) : value
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

/// `URLSessionTaskDelegate` только ради `didSendBodyData`: multipart-тело
/// кладётся в запрос целиком, но URLSession всё равно сообщает, сколько
/// байт уже ушло.
private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    private let handler: (Double) -> Void

    init(handler: @escaping (Double) -> Void) {
        self.handler = handler
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else { return }
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        handler(min(1, max(0, progress)))
    }
}
