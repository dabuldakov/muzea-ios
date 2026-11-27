import Foundation
import UIKit

/// Локальное хранилище сессии.
///
/// Секреты (access/refresh) — в Keychain. Идентификаторы и настройки — в
/// `UserDefaults`. Пароль больше не хранится: вход passwordless по email-коду,
/// а legacy-ключи (пароль и отдельный chat-токен) вычищаются при первом запуске.
final class TokenStore {
    /// Ключи, которыми владеет приложение. `auth_token`/`password`/`chat_token`
    /// оставлены только для миграции со старых версий.
    private static let ownedKeys = [
        "auth_token", "username", "email", "password",
        "chat_token", "chat_token_user", "chat_user_uuid",
        "fcm_token", "fcm_token_registered",
        "device_id"
    ]

    private let defaults: UserDefaults
    private let tokens: SecureTokenStoring

    /// Последнее успешно прочитанное/записанное значение токена.
    ///
    /// Keychain может быть временно недоступен (`errSecInteractionNotAllowed`),
    /// а запись — молча не сохраниться. Без такого кэша единичный сбой чтения
    /// выглядит как «пользователь разлогинен»: access-токен пропадает, запросы
    /// уходят без `Authorization`, а refresh даже не вызывается. Держим значения
    /// в памяти процесса как fallback до явной очистки сессии.
    private var cachedAccessToken: String?
    private var cachedRefreshToken: String?
    private var accessTokenLoaded = false
    private var refreshTokenLoaded = false
    private var sessionCleared = false
    private let cacheLock = NSLock()

    init(defaults: UserDefaults = .standard, tokens: SecureTokenStoring = KeychainTokenStore()) {
        self.defaults = defaults
        self.tokens = tokens
        KeychainTokenStore.deleteLegacyPassword()
        migrateLegacy()
    }

    // MARK: - Tokens (Keychain)

    var token: String? {
        get {
            cacheLock.lock()
            defer { cacheLock.unlock() }
            if sessionCleared { return nil }
            if let stored = tokens.accessToken {
                cachedAccessToken = stored
                accessTokenLoaded = true
                return stored
            }
            return accessTokenLoaded ? cachedAccessToken : nil
        }
        set {
            cacheLock.lock()
            defer { cacheLock.unlock() }
            sessionCleared = false
            cachedAccessToken = newValue
            accessTokenLoaded = true
            tokens.accessToken = newValue
        }
    }

    var refreshToken: String? {
        get {
            cacheLock.lock()
            defer { cacheLock.unlock() }
            if sessionCleared { return nil }
            if let stored = tokens.refreshToken {
                cachedRefreshToken = stored
                refreshTokenLoaded = true
                return stored
            }
            return refreshTokenLoaded ? cachedRefreshToken : nil
        }
        set {
            cacheLock.lock()
            defer { cacheLock.unlock() }
            sessionCleared = false
            cachedRefreshToken = newValue
            refreshTokenLoaded = true
            tokens.refreshToken = newValue
        }
    }

    // MARK: - Profile

    var username: String? {
        get { defaults.string(forKey: "username") }
        set { defaults.set(newValue, forKey: "username") }
    }

    var email: String? {
        get { defaults.string(forKey: "email") }
        set { defaults.set(newValue, forKey: "email") }
    }

    /// Локальный UUID пользователя на chat-сервере (создаётся при первом
    /// обращении к `/api/users/me`). Нужен для чатов/контактов.
    var chatUserUuid: String? {
        get { defaults.string(forKey: "chat_user_uuid") }
        set { defaults.set(newValue, forKey: "chat_user_uuid") }
    }

    // MARK: - Push / device

    var fcmToken: String? {
        get { defaults.string(forKey: "fcm_token") }
        set { defaults.set(newValue, forKey: "fcm_token") }
    }

    var registeredFcmToken: String? {
        get { defaults.string(forKey: "fcm_token_registered") }
        set { defaults.set(newValue, forKey: "fcm_token_registered") }
    }

    var deviceId: String {
        if let id = defaults.string(forKey: "device_id") { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: "device_id")
        return id
    }

    var deviceName: String { UIDevice.current.name }
    /// Больше не отправляется на сервер (у `/fcm-token` нет поля platform),
    /// оставлено для диагностики/логов.
    var deviceType: String { "IOS" }

    var isLoggedIn: Bool {
        !(token ?? "").isEmpty
    }

    // MARK: - Clearing

    /// Локальный выход: токены и профиль удаляются, deviceId и FCM-токен
    /// остаются (их можно переиспользовать после повторного входа).
    func clearSession() {
        resetTokenCache()
        ["username", "email", "chat_user_uuid", "fcm_token_registered", "password",
         "chat_token", "chat_token_user"].forEach {
            defaults.removeObject(forKey: $0)
        }
    }

    /// Сбрасываем и Keychain, и in-memory fallback. `sessionCleared` не даёт
    /// заново прочитать токен, если удаление из Keychain временно не удалось.
    private func resetTokenCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        sessionCleared = true
        cachedAccessToken = nil
        cachedRefreshToken = nil
        accessTokenLoaded = true
        refreshTokenLoaded = true
        tokens.clear()
    }

    /// Совместимое имя для существующего кода.
    func clear() {
        clearSession()
    }

    /// Полная очистка локальных данных пользователя — при удалении аккаунта
    /// или отзыве согласия на обработку персональных данных.
    func clearAll() {
        resetTokenCache()
        for key in Self.ownedKeys { defaults.removeObject(forKey: key) }
        // Подстраховка от ключей, добавленных в будущем.
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Migration

    /// Переход со старой схемы: `auth_token` из UserDefaults → Keychain;
    /// пароль и отдельный chat-токен больше не используются.
    private func migrateLegacy() {
        if (tokens.accessToken ?? "").isEmpty,
           let legacy = defaults.string(forKey: "auth_token"),
           !legacy.isEmpty {
            tokens.accessToken = legacy
        }
        ["auth_token", "password", "chat_token", "chat_token_user"].forEach {
            defaults.removeObject(forKey: $0)
        }
    }
}
