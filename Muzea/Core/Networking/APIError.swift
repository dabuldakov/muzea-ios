import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case server(Int, String)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return L10n.invalidURL
        case .unauthorized: return L10n.unauthorized
        case .server(let code, let message): return L10n.serverError(code, message)
        case .decoding(let error): return L10n.decodingError(error.localizedDescription)
        case .transport(let error): return L10n.transportError(error.localizedDescription)
        }
    }
}

struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void
    init(_ value: Encodable) { encodeClosure = value.encode }
    func encode(to encoder: Encoder) throws { try encodeClosure(encoder) }
}

enum ImageURL {
    static func makeup(_ path: String?) -> URL? { resolve(path, base: Config.makeupBaseURL) }
    static func chat(_ path: String?) -> URL? { resolve(path, base: Config.chatBaseURL) }

    private static func resolve(_ path: String?, base: URL) -> URL? {
        guard let path else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        let baseString = base.absoluteString.hasSuffix("/")
            ? String(base.absoluteString.dropLast())
            : base.absoluteString
        let suffix = trimmed.hasPrefix("/") ? trimmed : "/" + trimmed
        return URL(string: baseString + suffix)
    }
}
