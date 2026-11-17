import Foundation

/// Превью внешней ссылки из Open Graph.
struct LinkPreview: Equatable {
    let url: URL
    let title: String?
    let description: String?
    let imageURL: URL?
    let siteName: String?
}

/// Поиск первой ссылки в тексте сообщения.
enum LinkPreviewExtractor {
    private static let regex = try! NSRegularExpression(
        pattern: #"https?://[^\s<>"']+"#,
        options: [.caseInsensitive]
    )

    static func firstURL(in text: String?) -> URL? {
        guard let text, !text.isEmpty else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ) else { return nil }

        var raw = nsText.substring(with: match.range)
        while let last = raw.last, ".,;:!?)]}»\"'".contains(last) {
            raw.removeLast()
        }
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }
}

/// Разбор Open Graph/Twitter Card из HTML. Читает только первые килобайты,
/// как Android `OgParser`.
enum LinkPreviewParser {
    private static let metaRegex = try! NSRegularExpression(
        pattern: #"(?is)<meta\s+[^>]*>"#
    )
    private static let attributeRegex = try! NSRegularExpression(
        pattern: #"(?is)([a-z][a-z0-9:_-]*)\s*=\s*["']([^"']*)["']"#
    )
    private static let titleRegex = try! NSRegularExpression(
        pattern: #"(?is)<title[^>]*>(.*?)</title>"#
    )

    static func parse(_ html: String, baseURL: URL) -> LinkPreview? {
        let nsHTML = html as NSString
        var meta: [String: String] = [:]

        for match in metaRegex.matches(
            in: html,
            range: NSRange(location: 0, length: nsHTML.length)
        ) {
            let tag = nsHTML.substring(with: match.range)
            var attributes: [String: String] = [:]
            let nsTag = tag as NSString
            for attr in attributeRegex.matches(
                in: tag,
                range: NSRange(location: 0, length: nsTag.length)
            ) {
                let key = nsTag.substring(with: attr.range(at: 1)).lowercased()
                attributes[key] = decodeEntities(nsTag.substring(with: attr.range(at: 2)))
            }
            guard let content = attributes["content"], !content.isEmpty else { continue }
            for key in ["property", "name"] {
                if let name = attributes[key]?.lowercased() {
                    meta[name] = content
                }
            }
        }

        let title = first(meta, ["og:title", "twitter:title"])
            ?? firstTitle(html)
        let description = first(meta, ["og:description", "twitter:description", "description"])
        let imageRaw = first(meta, ["og:image", "twitter:image", "twitter:image:src"])
        let imageURL = imageRaw.flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL }
        let siteName = first(meta, ["og:site_name"])

        guard title != nil || description != nil || imageURL != nil else { return nil }
        return LinkPreview(
            url: baseURL,
            title: title,
            description: description,
            imageURL: imageURL,
            siteName: siteName
        )
    }

    private static func first(_ meta: [String: String], _ keys: [String]) -> String? {
        for key in keys {
            if let value = meta[key], !value.trimmingCharacters(in: .whitespaces).isEmpty {
                return value
            }
        }
        return nil
    }

    private static func firstTitle(_ html: String) -> String? {
        let nsHTML = html as NSString
        guard let match = titleRegex.firstMatch(
            in: html,
            range: NSRange(location: 0, length: nsHTML.length)
        ) else { return nil }
        let value = decodeEntities(nsHTML.substring(with: match.range(at: 1)))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    static func decodeEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}

/// Защита от SSRF: не тянем localhost, приватные и служебные адреса.
enum LinkPreviewSafety {
    static func isSafe(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty,
              !isBlockedHost(host) else { return false }

        // Для доменов проверяем и разрешённый адрес: DNS не должен вести внутрь.
        guard !isIPLiteral(host) else { return true }
        return !resolvesToPrivateAddress(host)
    }

    static func isBlockedHost(_ host: String) -> Bool {
        let normalized = host.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        if normalized.isEmpty { return true }
        if normalized == "localhost" || normalized.hasSuffix(".localhost")
            || normalized.hasSuffix(".local") || normalized.hasSuffix(".internal")
            || normalized == "metadata.google.internal" {
            return true
        }
        if !normalized.contains(".") && !normalized.contains(":") { return true }
        return isIPLiteral(normalized) ? isPrivateAddress(normalized) : false
    }

    private static func isIPLiteral(_ host: String) -> Bool {
        host.contains(":") || host.range(
            of: #"^\d{1,3}(\.\d{1,3}){3}$"#,
            options: .regularExpression
        ) != nil
    }

    private static func isPrivateAddress(_ host: String) -> Bool {
        var ipv4 = in_addr()
        if inet_pton(AF_INET, host, &ipv4) == 1 {
            let value = UInt32(bigEndian: ipv4.s_addr)
            let first = (value >> 24) & 0xFF
            let second = (value >> 16) & 0xFF
            if first == 0 || first == 10 || first == 127 { return true }
            if first == 169 && second == 254 { return true }
            if first == 172 && (16...31).contains(second) { return true }
            if first == 192 && second == 168 { return true }
            if first == 100 && (64...127).contains(second) { return true }
            if first >= 224 { return true }
            return false
        }

        var ipv6 = in6_addr()
        if inet_pton(AF_INET6, host, &ipv6) == 1 {
            let bytes = withUnsafeBytes(of: &ipv6) { Array($0) }
            if bytes.count == 16 {
                if bytes.allSatisfy({ $0 == 0 }) { return true } // ::
                let loopback = bytes.dropLast().allSatisfy { $0 == 0 } && bytes.last == 1
                if loopback { return true } // ::1
                if bytes[0] == 0xFE && (bytes[1] & 0xC0) == 0x80 { return true } // fe80::/10
                if (bytes[0] & 0xFE) == 0xFC { return true } // fc00::/7
                if bytes[0] == 0xFF { return true } // multicast
            }
        }
        return false
    }

    private static func resolvesToPrivateAddress(_ host: String) -> Bool {
        var hints = addrinfo(
            ai_flags: AI_ADDRCONFIG,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else {
            return true
        }
        defer { freeaddrinfo(result) }

        var current: UnsafeMutablePointer<addrinfo>? = first
        while let info = current {
            if let address = info.pointee.ai_addr {
                var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    address,
                    info.pointee.ai_addrlen,
                    &buffer,
                    socklen_t(buffer.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                ) == 0 {
                    let numeric = String(cString: buffer)
                    if isPrivateAddress(numeric) { return true }
                }
            }
            current = info.pointee.ai_next
        }
        return false
    }
}
