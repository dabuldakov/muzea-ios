import Foundation

#if DEBUG
/// Запуск с готовой сессией для CI-скриншотов App Store.
///
/// Код собирается только в Debug и никогда не попадает в релизную сборку.
/// Токены передаются через переменные окружения или аргументы запуска
/// симулятора, согласие на обработку данных принимается автоматически.
enum ScreenshotBootstrap {
    struct Session {
        let accessToken: String
        let refreshToken: String?
        let username: String?
    }

    static var session: Session? {
        guard let accessToken = value("MUZEA_SCREENSHOT_ACCESS"),
              !accessToken.isEmpty else {
            return nil
        }
        return Session(
            accessToken: accessToken,
            refreshToken: value("MUZEA_SCREENSHOT_REFRESH"),
            username: value("MUZEA_SCREENSHOT_USERNAME")
        )
    }

    static func apply(_ session: Session, store: TokenStore, consent: ConsentManager) {
        store.token = session.accessToken
        if let refreshToken = session.refreshToken, !refreshToken.isEmpty {
            store.refreshToken = refreshToken
        }
        if let username = session.username, !username.isEmpty {
            store.username = username
        }
        consent.accept()
    }

    /// Начальная вкладка для детерминированного скриншота.
    static var initialTab: Int? {
        guard let raw = value("MUZEA_SCREENSHOT_TAB"),
              let tab = Int(raw),
              (0...4).contains(tab) else {
            return nil
        }
        return tab
    }

    /// Карточка новости, открытая сразу при запуске (без URL-подтверждения).
    static var initialNews: Int64? {
        value("MUZEA_SCREENSHOT_NEWS").flatMap(Int64.init)
    }

    /// Переписка, открытая сразу при запуске (без URL-подтверждения).
    static var initialChat: Chat? {
        guard let uuid = value("MUZEA_SCREENSHOT_CHAT"), !uuid.isEmpty else {
            return nil
        }
        return Chat(
            chatUuid: uuid,
            chatType: nil,
            title: nil,
            avatarUrl: nil,
            createdAt: nil,
            updatedAt: nil,
            participantCount: nil,
            lastMessage: nil,
            unreadCount: 0
        )
    }

    private static func value(_ key: String) -> String? {
        if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
            return value
        }
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-\(key)"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}
#endif
