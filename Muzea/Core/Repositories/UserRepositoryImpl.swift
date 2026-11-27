import Foundation

/// Реализация `UserRepository`: профиль на основном бэкенде.
final class UserRepositoryImpl: UserRepository {
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func currentUser() async throws -> User {
        let dto: UserDTO = try await client.request("GET", "/api/users/me")
        return dto.toDomain()
    }

    func updateUser(id: Int64, fullName: String, email: String) async throws -> User {
        let dto: UserDTO = try await client.request(
            "PUT",
            "/api/users/\(id)",
            body: UpdateUserRequest(fullName: fullName, email: email, enabled: true)
        )
        return dto.toDomain()
    }

    /// Удаление профиля и контента на основном бэкенде: новости, видео, лайки,
    /// комментарии и файлы удаляются. 404 считается успехом при повторной попытке.
    ///
    /// 404 считается успехом: аккаунт мог быть деактивирован при предыдущей
    /// попытке, где чат-сервер отвечает раньше основного.
    func deleteAccount(id: Int64) async throws {
        do {
            try await client.requestVoid("DELETE", "/api/users/\(id)")
        } catch APIError.server(let code, _) where code == 404 {
            return
        }
    }
}
