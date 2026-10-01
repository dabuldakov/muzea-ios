import Foundation
import Security

/// Хранение пароля от учётной записи в Keychain.
///
/// Открытый текст в `UserDefaults` недопустим: файл доступен другим приложениям
/// с правами root/backup. Если хранилище недоступно, пароль не сохраняется вовсе —
/// чат просто потребует повторного входа через приложение.
protocol PasswordStoring: AnyObject {
    var password: String? { get set }
    func clear()
}

/// Заглушка для тестов: держит пароль в памяти процесса.
final class InMemoryPasswordStore: PasswordStoring {
    var password: String?
    func clear() { password = nil }
}

final class KeychainPasswordStore: PasswordStoring {
    private let service: String
    private let account: String

    init(service: String = "com.example.muzea", account: String = "account_password") {
        self.service = service
        self.account = account
    }

    var password: String? {
        get { read() }
        set {
            if let newValue {
                write(newValue)
            } else {
                clear()
            }
        }
    }

    func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func read() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            // Пароль нужен фоновой переавторизации чата после перезапуска,
            // поэтому хранилище должно быть доступно без первого разблокирования.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecItemNotFound else { return }

        var insert = query
        insert.merge(attributes) { _, new in new }
        SecItemAdd(insert as CFDictionary, nil)
    }
}
