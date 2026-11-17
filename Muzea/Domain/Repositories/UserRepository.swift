import Foundation

/// Профиль пользователя на основном бэкенде: чтение, правка и удаление аккаунта.

protocol UserRepository {
    func currentUser() async throws -> User
    func updateUser(id: Int64, fullName: String, email: String) async throws -> User
    func deleteAccount(id: Int64) async throws
}

/// Авторизация на едином IdP. Отделена от профиля: у неё свой жизненный цикл
/// (токены/секреты), а у профиля — только данные пользователя.
/// Чем закончился запрос кода входа. Сервер знает про аккаунт, но текст
/// ответа остаётся нейтральным — статус нужен только своему клиенту.
enum LoginCodeStatus: Equatable {
    case sent
    case notFound
    case unverified
    case deleted
    /// Старый сервер без поля `status`: ведём себя как раньше.
    case unknown
}

protocol AuthRepositoryProtocol {
    var isLoggedIn: Bool { get }

    /// Регистрация: создаёт пользователя и отправляет код на email.
    func register(email: String, username: String, displayName: String?) async throws
    /// Подтверждение email кодом: активирует аккаунт и сразу логинит.
    func verifyEmail(email: String, code: String) async throws
    func resendVerification(email: String) async throws

    /// Вход по коду (passwordless). Возвращает, существует ли аккаунт.
    func requestLoginCode(email: String) async throws -> LoginCodeStatus
    func verifyLoginCode(email: String, code: String) async throws

    /// Профиль IdP (email/username/displayName/emailVerified).
    func currentUser() async throws -> AuthServiceUser
    /// Удаление аккаунта в IdP.
    func deleteAccount() async throws

    /// Локальный выход + best-effort отзыв refresh-сессии.
    func logout() async
    /// Локальная очистка без обращения к серверу (после удаления аккаунта).
    func clearLocalSession()
}
