import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case server(Int, String)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Некорректный адрес запроса"
        case .unauthorized: return "Требуется авторизация"
        case .server(let code, let message): return "Ошибка сервера (\(code)): \(message)"
        case .decoding(let error): return "Ошибка разбора ответа: \(error.localizedDescription)"
        case .transport(let error): return "Сетевая ошибка: \(error.localizedDescription)"
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
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        let baseString = base.absoluteString.hasSuffix("/")
            ? String(base.absoluteString.dropLast())
            : base.absoluteString
        let suffix = path.hasPrefix("/") ? path : "/" + path
        return URL(string: baseString + suffix)
    }
}
