import Foundation

/// Дисковый кэш первых страниц GIF. Гифки не меняются, поэтому TTL 30 минут;
/// при ошибке сети отдаём устаревший кэш вместо пустоты.
actor GifCache {
    static let shared = GifCache()

    private struct Entry: Codable {
        let items: [Gif]
        let at: Date
    }

    private let fileURL: URL
    private var entries: [String: Entry]?

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let directory = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.fileURL = directory.appendingPathComponent("gif-cache.json")
        }
    }

    func fresh(key: String, ttl: TimeInterval) -> [Gif]? {
        guard let entry = load()[key], Date().timeIntervalSince(entry.at) < ttl else {
            return nil
        }
        return entry.items
    }

    func stale(key: String) -> [Gif]? {
        load()[key]?.items
    }

    func put(key: String, items: [Gif]) {
        guard !items.isEmpty else { return }
        var all = load()
        all[key] = Entry(items: items, at: Date())
        // Не даём кэшу расти бесконечно: старые запросы и лишние ключи уходят.
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        all = all.filter { $0.value.at > cutoff }
        if all.count > 200 {
            let keep = all.sorted { $0.value.at > $1.value.at }.prefix(200)
            all = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
        }
        persist(all)
    }

    /// Только что отправленная гифка должна сразу быть в «Мои» и «Этот чат»,
    /// не дожидаясь истечения TTL первой страницы (как `cacheSentGif` на Android).
    func prepend(key: String, item: Gif, limit: Int = 60) {
        var all = load()
        let existing = all[key]?.items ?? []
        let merged = [item] + existing.filter { $0.providerGifId != item.providerGifId }
        all[key] = Entry(items: Array(merged.prefix(limit)), at: Date())
        persist(all)
    }

    private func persist(_ all: [String: Entry]) {
        entries = all
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if let data = try? JSONEncoder().encode(all) {
            try? data.write(to: fileURL, options: .atomic)
            FileProtection.apply(to: fileURL)
        }
    }

    func clearAll() {
        entries = [:]
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func load() -> [String: Entry] {
        if let entries { return entries }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            entries = [:]
            return [:]
        }
        entries = decoded
        return decoded
    }
}

/// Klipy GIF API: запросы идут с устройства напрямую, ключ встроен в сборку.
final class KlipyGifRepository: GifRepository {
    static let contentFilter = "high"
    static let freshTTL: TimeInterval = 30 * 60

    private let apiKey: String
    private let session: URLSession
    private let cache: GifCache
    private let auth: ChatAuthorization?

    init(
        apiKey: String = Config.klipyAppKey,
        session: URLSession = .shared,
        cache: GifCache = .shared,
        auth: ChatAuthorization? = nil
    ) {
        self.apiKey = apiKey
        self.session = session
        self.cache = cache
        self.auth = auth
    }

    func search(query: String, page: Int, size: Int) async -> [Gif] {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let key = cacheKey(query: query, page: page)
        if page == 0, let fresh = await cache.fresh(key: key, ttl: Self.freshTTL) {
            return fresh
        }

        let fetched = await fetch(query: query, page: page, size: size)
        if page == 0 {
            if !fetched.isEmpty {
                await cache.put(key: key, items: fetched)
                return fetched
            }
            return await cache.stale(key: key) ?? []
        }
        return fetched
    }

    private func cacheKey(query: String, page: Int) -> String {
        "\(query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())#\(page)"
    }

    func recent(page: Int, size: Int) async -> [Gif] {
        await serverList(
            path: "/api/gifs/recent",
            key: "recent#\(page)",
            page: page,
            size: size
        )
    }

    func chat(chatUuid: String, page: Int, size: Int) async -> [Gif] {
        await serverList(
            path: "/api/gifs/chat/\(chatUuid)",
            key: "chat-\(chatUuid)#\(page)",
            page: page,
            size: size
        )
    }

    func cacheSentGif(chatUuid: String, gif: Gif, mine: Bool) async {
        await cache.prepend(key: "chat-\(chatUuid)#0", item: gif)
        if mine {
            await cache.prepend(key: "recent#0", item: gif)
        }
    }

    private func serverList(
        path: String,
        key: String,
        page: Int,
        size: Int
    ) async -> [Gif] {
        guard let auth else { return [] }
        if page == 0, let fresh = await cache.fresh(key: key, ttl: Self.freshTTL) {
            return fresh
        }
        do {
            let dtos: [GifDTO] = try await auth.authorized {
                try await auth.client.request(
                    "GET",
                    path,
                    query: [
                        URLQueryItem(name: "page", value: "\(page)"),
                        URLQueryItem(name: "size", value: "\(size)")
                    ]
                )
            }
            let items = dtos.map { $0.toDomain() }
            if page == 0, !items.isEmpty {
                await cache.put(key: key, items: items)
            }
            return items.isEmpty && page == 0
                ? (await cache.stale(key: key) ?? [])
                : items
        } catch {
            return page == 0 ? (await cache.stale(key: key) ?? []) : []
        }
    }

    private func fetch(query: String, page: Int, size: Int) async -> [Gif] {
        var components = URLComponents(string: "https://api.klipy.com")
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        components?.path = "/api/v1/\(apiKey)/gifs/\(trimmed.isEmpty ? "trending" : "search")"
        components?.queryItems = [
            URLQueryItem(name: "page", value: "\(page + 1)"),
            URLQueryItem(name: "per_page", value: "\(size)"),
            URLQueryItem(name: "content_filter", value: Self.contentFilter)
        ]
        if !trimmed.isEmpty {
            components?.queryItems?.append(URLQueryItem(name: "q", value: trimmed))
        }
        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else { return [] }
            return Self.parse(data)
        } catch {
            return []
        }
    }

    static func parse(_ data: Data) -> [Gif] {
        guard let response = try? JSONDecoder().decode(KlipyResponse.self, from: data) else {
            return []
        }
        return response.data?.items?.compactMap(map) ?? []
    }

    private static func map(_ item: KlipyItem) -> Gif? {
        guard let sizes = item.file else { return nil }
        let animated = media(sizes, sizes: ["hd", "md", "sm"], formats: ["webp", "gif"])
            ?? sizes.values.lazy.compactMap { $0["webp"] ?? $0["gif"] }.first
        guard let url = animated?.url else { return nil }

        let preview = media(sizes, sizes: ["sm", "md"], formats: ["jpg", "webp"])?.url ?? url
        let mp4 = media(sizes, sizes: ["hd", "md", "sm"], formats: ["mp4"])?.url
            ?? sizes.values.lazy.compactMap { $0["mp4"]?.url }.first
        guard let identifier = item.slug ?? item.id.map({ String($0) }) else { return nil }

        return Gif(
            provider: "klipy",
            providerGifId: identifier,
            title: item.title,
            url: url,
            previewUrl: preview,
            mp4Url: mp4,
            width: animated?.width,
            height: animated?.height,
            gifKey: nil
        )
    }

    private static func media(
        _ sizes: [String: [String: KlipyMedia]],
        sizes order: [String],
        formats: [String]
    ) -> KlipyMedia? {
        for size in order {
            for format in formats {
                if let media = sizes[size]?[format] {
                    return media
                }
            }
        }
        return nil
    }

    private struct KlipyResponse: Decodable {
        let data: Page?

        struct Page: Decodable {
            let items: [KlipyItem]?

            enum CodingKeys: String, CodingKey {
                case items = "data"
            }
        }
    }

    private struct KlipyItem: Decodable {
        let id: Int64?
        let slug: String?
        let title: String?
        let file: [String: [String: KlipyMedia]]?
    }

    private struct KlipyMedia: Decodable {
        let url: String?
        let width: Int?
        let height: Int?
    }
}
