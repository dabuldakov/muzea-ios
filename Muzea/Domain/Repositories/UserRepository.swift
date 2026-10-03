import Foundation

/// Профиль пользователя на основном бэкенде: чтение, правка и удаление аккаунта.

protocol UserRepository {
    func currentUser() async throws -> UserResponse
    func updateUser(id: Int64, fullName: String, email: String) async throws -> UserResponse
    func deleteAccount(id: Int64) async throws
}

/// Авторизация на основном бэкенде. Отделена от профиля: у неё свой жизненный
/// цикл (токены/секреты), а у профиля — только данные пользователя.
protocol AuthRepositoryProtocol {
    func login(username: String, password: String) async throws -> AuthResponse
    func register(username: String, email: String, password: String, fullName: String) async throws -> AuthResponse
    func logout()
}
