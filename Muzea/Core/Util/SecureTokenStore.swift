import Foundation
import os
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

    private static let logger = Logger(subsystem: "com.cyber.muzea", category: "Keychain")

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
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            // Не выдаём ошибку за «токена нет»: наверху это выглядит как
            // разлогин. Значение не логируем — только код ошибки.
            Self.logger.error("keychain read failed account=\(account, privacy: .public) status=\(status)")
            return nil
        }
    }

    private func write(_ value: String?, account: String) {
        guard let value, !value.isEmpty else {
            delete(account)
            return
        }
        guard let data = value.data(using: .utf8) else { return }
        let query = baseQuery(account)
        let valueAttributes: [String: Any] = [kSecValueData as String: data]

        // `kSecAttrAccessible` нельзя менять через SecItemUpdate (iOS вернёт
        // errSecParam), поэтому он передаётся только при вставке.
        let updateStatus = SecItemUpdate(query as CFDictionary, valueAttributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            add(data, account: account, query: query, valueAttributes: valueAttributes)
        default:
            Self.logger.error("keychain update failed account=\(account, privacy: .public) status=\(updateStatus)")
            // errSecParam — несовместимый/повреждённый элемент, его нужно
            // пересоздать. Временные ошибки (например, устройство заблокировано)
            // не должны удалять уже сохранённый токен.
            if updateStatus == errSecParam {
                SecItemDelete(query as CFDictionary)
                add(data, account: account, query: query, valueAttributes: valueAttributes)
            }
        }
    }

    private func add(
        _ data: Data,
        account: String,
        query: [String: Any],
        valueAttributes: [String: Any]
    ) {
        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        var status = SecItemAdd(insert as CFDictionary, nil)

        // Другой поток мог вставить элемент между update и add: обновляем его,
        // иначе новый токен потеряется.
        if status == errSecDuplicateItem {
            status = SecItemUpdate(query as CFDictionary, valueAttributes as CFDictionary)
        }
        if status != errSecSuccess {
            Self.logger.error("keychain write failed account=\(account, privacy: .public) status=\(status)")
        }
    }

    private func delete(_ account: String) {
        let status = SecItemDelete(baseQuery(account) as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            Self.logger.error("keychain delete failed account=\(account, privacy: .public) status=\(status)")
        }
    }
}
