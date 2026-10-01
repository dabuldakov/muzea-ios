import Foundation
import UIKit

/// Локальное хранилище сессии, по ключам совпадает с Android TokenManager.
/// Пароль хранится в Keychain, а не в UserDefaults (аналог SecurePasswordStore).
final class TokenStore {
    /// Ключи, которыми владеет приложение: сессия, чат, push, устройство.
    private static let ownedKeys = [
        "auth_token", "username", "email", "password",
        "chat_token", "chat_token_user",
        "fcm_token", "fcm_token_registered",
        "device_id"
    ]

    private let defaults: UserDefaults
    private let passwordStore: PasswordStoring

    init(defaults: UserDefaults = .standard, passwordStore: PasswordStoring = KeychainPasswordStore()) {
        self.defaults = defaults
        self.passwordStore = passwordStore
        migrateLegacyPassword()
    }

    var token: String? {
        get { defaults.string(forKey: "auth_token") }
        set { defaults.set(newValue, forKey: "auth_token") }
    }

    var username: String? {
        get { defaults.string(forKey: "username") }
        set { defaults.set(newValue, forKey: "username") }
    }

    var email: String? {
        get { defaults.string(forKey: "email") }
        set { defaults.set(newValue, forKey: "email") }
    }

    var password: String? {
        get { passwordStore.password }
        set { passwordStore.password = newValue }
    }

    var chatToken: String? {
        get { defaults.string(forKey: "chat_token") }
        set { defaults.set(newValue, forKey: "chat_token") }
    }

    var chatTokenUser: String? {
        get { defaults.string(forKey: "chat_token_user") }
        set { defaults.set(newValue, forKey: "chat_token_user") }
    }

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
    var deviceType: String { "IOS" }

    var isLoggedIn: Bool {
        !(token ?? "").isEmpty && !(username ?? "").isEmpty
    }

    func clear() {
        ["auth_token", "username", "chat_token", "chat_token_user"].forEach {
            defaults.removeObject(forKey: $0)
        }
        passwordStore.clear()
    }

    /// Полная очистка локальных данных пользователя — при удалении аккаунта
    /// или отзыве согласия на обработку персональных данных.
    func clearAll() {
        for key in Self.ownedKeys { defaults.removeObject(forKey: key) }
        // Подстраховка от ключей, добавленных в будущем.
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
        passwordStore.clear()
    }

    /// Ранее пароль лежал в UserDefaults открытым текстом. Переносим его в Keychain
    /// и удаляем из обычных настроек.
    private func migrateLegacyPassword() {
        let legacy = defaults.string(forKey: "password")
        guard let legacy, !legacy.isEmpty else { return }
        if passwordStore.password == nil {
            passwordStore.password = legacy
        }
        defaults.removeObject(forKey: "password")
    }
}
