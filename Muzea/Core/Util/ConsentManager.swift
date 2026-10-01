import Foundation

/// Согласие пользователя на обработку персональных данных (ст. 9 ФЗ-152).
///
/// Хранится версия согласия: при смене редакции политики экран согласия
/// показывается заново, даже если пользователь уже принимал предыдущую.
final class ConsentManager {
    private enum Key {
        static let acceptedVersion = "accepted_version"
        static let acceptedAt = "accepted_at"
    }

    private let defaults: UserDefaults
    private let version: Int

    init(defaults: UserDefaults = .standard, version: Int = Legal.consentVersion) {
        self.defaults = defaults
        self.version = version
    }

    var isAccepted: Bool {
        defaults.integer(forKey: Key.acceptedVersion) == version
    }

    var acceptedAt: Date? {
        let millis = defaults.double(forKey: Key.acceptedAt)
        guard millis > 0 else { return nil }
        return Date(timeIntervalSince1970: millis / 1000)
    }

    func accept() {
        defaults.set(version, forKey: Key.acceptedVersion)
        defaults.set(Date().timeIntervalSince1970 * 1000, forKey: Key.acceptedAt)
    }

    func revoke() {
        defaults.removeObject(forKey: Key.acceptedVersion)
        defaults.removeObject(forKey: Key.acceptedAt)
    }
}
