import Foundation

/// Единая политика защиты файлов приложения. Данные должны быть доступны
/// после первой разблокировки (фоновые загрузки/пуш), но не до неё.
enum FileProtection {
    static let type: FileProtectionType = .completeUntilFirstUserAuthentication

    static func apply(to url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: type],
            ofItemAtPath: url.path
        )
    }

    static func apply(toDirectory url: URL) {
        apply(to: url)
    }
}
