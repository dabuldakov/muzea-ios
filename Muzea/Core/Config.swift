import Foundation

enum Config {
    static let makeupBaseURL = URL(string: "https://api-muzea.su")!
    static let chatBaseURL = URL(string: "https://chat-muzea.su")!

    static let newsPageSize = 20
    static let messagePageSize = 50
    static let chatPollInterval: UInt64 = 3_000_000_000 // 3s in nanoseconds
    static let chatListRefreshInterval: UInt64 = 8_000_000_000 // 8s
    static let unreadPollInterval: UInt64 = 10_000_000_000 // 10s

    /// Ограничение на размер загружаемого аватара (профиля и группы).
    static let maxAvatarBytes = 5 * 1024 * 1024
}
