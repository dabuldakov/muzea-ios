import Foundation

enum Config {
    static let makeupBaseURL = URL(string: "https://api-muzea.su")!
    static let chatBaseURL = URL(string: "https://chat-muzea.su")!

    static let newsPageSize = 20
    static let messagePageSize = 50
    static let chatPollInterval: UInt64 = 3_000_000_000 // 3s in nanoseconds
    static let chatListRefreshInterval: UInt64 = 8_000_000_000 // 8s
    static let unreadPollInterval: UInt64 = 10_000_000_000 // 10s

    /// Heartbeat «приложение на переднем плане». Сервер держит «онлайн» 45 секунд
    /// после последнего удара, поэтому 15 секунд переживают потерю пары запросов.
    static let heartbeatInterval: UInt64 = 15_000_000_000 // 15s

    /// Опрос статусов контактов, пока открыт экран контактов.
    static let presencePollInterval: UInt64 = 20_000_000_000 // 20s

    /// Размер чанка batch-запроса присутствия: сервер ограничивает пачку, а URL
    /// со списком UUID не должен разрастаться до проблем у прокси.
    static let presenceBatchSize = 100

    /// Ограничение на размер загружаемого аватара (профиля и группы).
    static let maxAvatarBytes = 5 * 1024 * 1024
}
