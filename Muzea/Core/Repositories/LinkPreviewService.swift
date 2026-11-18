import Foundation

/// Загрузка и кэширование Open Graph превью. Ходит на произвольные сайты,
/// поэтому каждый URL и каждый редирект проверяются `LinkPreviewSafety`.
actor LinkPreviewService {
    static let shared = LinkPreviewService()

    private struct Entry {
        let preview: LinkPreview?
        let at: Date
    }

    private var cache: [String: Entry] = [:]
    private let ttl: TimeInterval
    private let maxBytes = 512 * 1024

    private let session: URLSession

    /// `session` и `ttl` параметризованы для тестов: без подмены сессии
    /// сервис ходил бы в реальную сеть.
    init(session: URLSession? = nil, ttl: TimeInterval = 24 * 60 * 60) {
        self.ttl = ttl
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 8
            configuration.timeoutIntervalForResource = 10
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
    }

    func load(_ url: URL) async -> LinkPreview? {
        let key = url.absoluteString
        if let entry = cache[key], Date().timeIntervalSince(entry.at) < ttl {
            return entry.preview
        }

        let preview = await fetch(url)
        if let preview {
            cache[key] = Entry(preview: preview, at: Date())
        }
        return preview
    }

    private func fetch(_ url: URL) async -> LinkPreview? {
        guard LinkPreviewSafety.isSafe(url) else { return nil }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (compatible; Muzea/1.0)",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(
            "text/html,application/xhtml+xml",
            forHTTPHeaderField: "Accept"
        )

        do {
            let delegate = LinkPreviewRedirectGuard()
            let (stream, response) = try await session.bytes(for: request, delegate: delegate)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  http.mimeType?.lowercased().contains("html") == true else {
                return nil
            }

            // Читаем не больше maxBytes: чужой сервер может отдать гигабайты.
            var data = Data()
            data.reserveCapacity(min(maxBytes, 64 * 1024))
            for try await byte in stream {
                data.append(byte)
                if data.count >= maxBytes { break }
            }
            guard !data.isEmpty else { return nil }
            let html = String(decoding: data, as: UTF8.self)
            guard let preview = LinkPreviewParser.parse(html, baseURL: http.url ?? url) else {
                return nil
            }
            // og:image грузится уже устройством, поэтому внутренние адреса
            // отбрасываем так же, как и для самого HTML.
            if let image = preview.imageURL, !LinkPreviewSafety.isSafe(image) {
                return LinkPreview(
                    url: preview.url,
                    title: preview.title,
                    description: preview.description,
                    imageURL: nil,
                    siteName: preview.siteName
                )
            }
            return preview
        } catch {
            return nil
        }
    }
}

/// Не даёт URLSession уйти на локальный адрес через редирект.
private final class LinkPreviewRedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url, LinkPreviewSafety.isSafe(url) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}
