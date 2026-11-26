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
}
#endif
