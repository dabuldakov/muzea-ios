import Foundation
import Security

/// Хранилище access/refresh токенов. В отличие от пароля, токены нужны для
/// фоновой переавторизации, поэтому Keychain доступен после первой разблокировки.
protocol SecureTokenStoring: AnyObject {
    var accessToken: String? { get set }
    var refreshToken: String? { get set }
    func clear()
}

/// Заглушка для тестов: токены живут в памяти процесса.
final class InMemoryTokenStore: SecureTokenStoring {
    var accessToken: String?
    var refreshToken: String?
    func clear() {
        accessToken = nil
        refreshToken = nil
    }
}

final class KeychainTokenStore: SecureTokenStoring {
    private enum Account {
        static let access = "access_token"
        static let refresh = "refresh_token"
    }

    private let service: String

    init(service: String = "com.cyber.muzea") {
        self.service = service
    }

    var accessToken: String? {
        get { read(Account.access) }
        set { write(newValue, account: Account.access) }
    }

    var refreshToken: String? {
        get { read(Account.refresh) }
        set { write(newValue, account: Account.refresh) }
    }

    func clear() {
        delete(Account.access)
        delete(Account.refresh)
    }

    /// Старый пароль лежал в Keychain под прежним bundle id. После перехода на
    /// passwordless-вход он не нужен и должен быть уничтожен.
    static func deleteLegacyPassword() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.example.muzea",
            kSecAttrAccount as String: "account_password"
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func read(_ account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ value: String?, account: String) {
        guard let value, !value.isEmpty else {
            delete(account)
            return
        }
        guard let data = value.data(using: .utf8) else { return }
        let query = baseQuery(account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecItemNotFound else { return }

        var insert = query
        insert.merge(attributes) { _, new in new }
        SecItemAdd(insert as CFDictionary, nil)
    }

    private func delete(_ account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }
}
