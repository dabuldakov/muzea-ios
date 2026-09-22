import Foundation

/// Перехватывает все запросы URLSession с этим протоколом, чтобы тестировать
/// сетевой слой без реальной сети. Аналог MockWebServer на Android.
final class MockURLProtocol: URLProtocol {
    /// Обработчик запроса: возвращает HTTP-ответ и тело.
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    /// Все запросы, прошедшие через протокол (в порядке поступления).
    static private(set) var requests: [URLRequest] = []

    static func reset() {
        handler = nil
        requests = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.requests.append(request)

        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    // MARK: - Helpers

    static func response(
        for request: URLRequest,
        status: Int = 200,
        headers: [String: String] = ["Content-Type": "application/json"]
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url ?? URL(string: "http://localhost")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
    }
}

extension URLRequest {
    /// Тело запроса. URLSession может отдать его как поток, поэтому читаем и поток.
    var capturedBody: Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let size = 4096
        var buffer = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}