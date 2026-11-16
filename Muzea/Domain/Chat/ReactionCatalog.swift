import Foundation

/// Полный набор реакций и лимиты, как на Android.
enum ReactionCatalog {
    static let all = [
        "👍", "❤️", "😂", "😮", "😢", "🔥", "🎉", "👏",
        "🙏", "💯", "😍", "🤔", "😡", "🥰", "😎", "🤝",
        "✅", "❌", "👀", "🤯", "😴", "💜", "⚡", "🚀"
    ]
    static let recentLimit = 15
    static let stripLimit = 11
}

/// Последние использованные реакции. Хранится локально, как
/// `ReactionHistory` на Android.
protocol ReactionHistoryStore {
    func recent() -> [String]
    func record(_ emoji: String)
}

final class UserDefaultsReactionHistoryStore: ReactionHistoryStore {
    private let defaults: UserDefaults
    private let key = "chat.recentReactions"
    private let separator = "|"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func recent() -> [String] {
        let stored = defaults.string(forKey: key)?
            .split(separator: Character(separator))
            .map(String.init)
            .filter { !$0.isEmpty } ?? []
        return Array((stored.isEmpty ? ReactionCatalog.all : stored).prefix(ReactionCatalog.recentLimit))
    }

    func record(_ emoji: String) {
        let updated = ([emoji] + recent().filter { $0 != emoji })
            .prefix(ReactionCatalog.recentLimit)
        defaults.set(updated.joined(separator: separator), forKey: key)
    }
}
