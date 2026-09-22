import Foundation
import UIKit

/// Локальное хранилище сессии, по ключам совпадает с Android TokenManager.
final class TokenStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
        get { defaults.string(forKey: "password") }
        set { defaults.set(newValue, forKey: "password") }
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
    }
}
