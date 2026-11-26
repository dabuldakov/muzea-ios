import Foundation

#if DEBUG
/// Запуск с готовой сессией для CI-скриншотов App Store.
///
/// Код собирается только в Debug и никогда не попадает в релизную сборку.
/// Токены передаются через переменные окружения симулятора, согласие на
/// обработку данных принимается автоматически, чтобы не снимать экран согласия.
enum ScreenshotBootstrap {
    static func apply(store: TokenStore, consent: ConsentManager) {
        let environment = ProcessInfo.processInfo.environment
        guard let accessToken = environment["MUZEA_SCREENSHOT_ACCESS"],
              !accessToken.isEmpty else {
            return
        }
        store.token = accessToken
        if let refreshToken = environment["MUZEA_SCREENSHOT_REFRESH"],
           !refreshToken.isEmpty {
            store.refreshToken = refreshToken
        }
        consent.accept()
    }

    /// Начальная вкладка для детерминированного скриншота.
    static var initialTab: Int? {
        let raw = ProcessInfo.processInfo.environment["MUZEA_SCREENSHOT_TAB"] ?? ""
        guard let tab = Int(raw), (0...4).contains(tab) else { return nil }
        return tab
    }

    /// Карточка новости, открытая сразу при запуске (без URL-подтверждения).
    static var initialNews: Int64? {
        let raw = ProcessInfo.processInfo.environment["MUZEA_SCREENSHOT_NEWS"] ?? ""
        return Int64(raw)
    }

    /// Переписка, открытая сразу при запуске (без URL-подтверждения).
    static var initialChat: Chat? {
        let uuid = ProcessInfo.processInfo.environment["MUZEA_SCREENSHOT_CHAT"] ?? ""
        guard !uuid.isEmpty else { return nil }
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
}
#endif
