import Foundation

/// Реализация `AvatarRepository`: аватар профиля и аватар группы.
final class AvatarRepositoryImpl: AvatarRepository {
    private let auth: ChatAuthorization

    init(auth: ChatAuthorization) {
        self.auth = auth
    }

    func loadAvatar() async throws -> String? {
        let user: ChatUserResponse = try await auth.authorized {
            try await auth.client.request("GET", "/api/users/me")
        }
        return user.avatarUrl
    }

    func uploadAvatar(data: Data, fileName: String, mimeType: String) async throws -> String? {
        let response: AvatarResponse = try await auth.authorized {
            try await auth.client.upload(
                "/api/users/me/avatar",
                fields: [:],
                files: [
                    MultipartFile(field: "file", fileName: fileName, mimeType: mimeType, data: data)
                ]
            )
        }
        return response.avatarUrl
    }

    func deleteAvatar() async throws {
        try await auth.authorized { try await auth.client.requestVoid("DELETE", "/api/users/me/avatar") }
    }

    /// Загружает аватар группы; сервер отвечает относительным путём картинки.
    func uploadChatAvatar(chatUuid: String, data: Data, fileName: String, mimeType: String) async throws -> String? {
        let raw: Data = try await auth.authorized {
            try await auth.client.uploadData(
                "/api/chats/\(chatUuid)/avatar",
                fields: [:],
                files: [
                    MultipartFile(field: "file", fileName: fileName, mimeType: mimeType, data: data)
                ]
            )
        }
        return String(data: raw, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
