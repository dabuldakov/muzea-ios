import Foundation

/// Черновики сообщений по чатам. UserDefaults достаточно: текст должен пережить
/// выход из чата и перезапуск, но никуда не отправляется автоматически.
final class UserDefaultsChatDraftStore: ChatDraftStore {
    private let defaults: UserDefaults
    private let prefix = "chat.draft."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func draft(chatUuid: String) -> String? {
        guard !chatUuid.isEmpty else { return nil }
        let value = defaults.string(forKey: prefix + chatUuid)
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }

    func save(chatUuid: String, text: String?) {
        guard !chatUuid.isEmpty else { return }
        let key = prefix + chatUuid
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            defaults.set(text, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func clear(chatUuid: String) {
        guard !chatUuid.isEmpty else { return }
        defaults.removeObject(forKey: prefix + chatUuid)
    }

    func clearAll() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
