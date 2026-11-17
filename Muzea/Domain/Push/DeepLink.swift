import Foundation

/// Разбор внешних ссылок: `muzea://chat/...`, `muzea://news/...`,
/// `muzea://share?...` и HTTPS-вариантов для Universal Links.
enum DeepLink: Equatable {
    case chat(ChatPushTarget)
    case news(id: Int64)
    case share(text: String)

    static func parse(_ url: URL) -> DeepLink? {
        let scheme = url.scheme?.lowercased()
        if scheme == "muzea" {
            return parsePath(url)
        }
        if scheme == "https", url.host?.lowercased() == "muzea.su" {
            return parsePath(url)
        }
        return nil
    }

    private static func parsePath(_ url: URL) -> DeepLink? {
        var components = url.pathComponents.filter { $0 != "/" }
        if url.scheme?.lowercased() == "muzea",
           let host = url.host,
           !host.isEmpty {
            components.insert(host, at: 0)
        }
        guard let first = components.first?.lowercased() else { return nil }

        switch first {
        case "chat" where components.count >= 2:
            let uuid = components[1]
            guard !uuid.isEmpty else { return nil }
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            return .chat(ChatPushTarget(
                chatUuid: uuid,
                title: value("title", in: query),
                avatarUrl: value("avatar", in: query),
                messageUuid: value("message", in: query)
            ))
        case "news" where components.count >= 2:
            guard let id = Int64(components[1]) else { return nil }
            return .news(id: id)
        case "share":
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            guard let text = value("text", in: query), !text.isEmpty else { return nil }
            return .share(text: text)
        default:
            return nil
        }
    }

    private static func value(_ name: String, in items: [URLQueryItem]?) -> String? {
        items?.first { $0.name == name }?.value
    }
}
