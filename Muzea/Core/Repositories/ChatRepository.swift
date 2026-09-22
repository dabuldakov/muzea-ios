import Foundation

final class ChatRepository {
    private let client: HTTPClient
    private let auth: ChatAuthManager

    init(client: HTTPClient, auth: ChatAuthManager) {
        self.client = client
        self.auth = auth
    }

    private func authorized<T>(_ operation: () async throws -> T) async throws -> T {
        guard await auth.ensureAuthenticated() else { throw APIError.unauthorized }
        do {
            return try await operation()
        } catch APIError.unauthorized {
            auth.invalidate()
            guard await auth.ensureAuthenticated() else { throw APIError.unauthorized }
            return try await operation()
        }
    }

    // MARK: - Chats

    func loadChats() async throws -> [ChatResponse] {
        try await authorized { try await client.request("GET", "/api/chats") }
    }

    func totalUnreadCount() async throws -> Int64 {
        let response: UnreadCountResponse = try await authorized {
            try await client.request("GET", "/api/chats/unread-count/all")
        }
        return response.count
    }

    func createPrivateChat(userUuid: String) async throws -> ChatResponse {
        try await authorized {
            try await client.request("POST", "/api/chats/private", body: CreatePrivateChatRequest(otherUserUuid: userUuid))
        }
    }

    func createGroupChat(title: String, memberUuids: [String]) async throws -> ChatResponse {
        try await authorized {
            try await client.request(
                "POST",
                "/api/chats/group",
                body: CreateGroupChatRequest(title: title, memberUuids: memberUuids)
            )
        }
    }

    func loadChatParticipants(chatUuid: String) async throws -> [ChatParticipantResponse] {
        try await authorized {
            try await client.request("GET", "/api/chats/\(chatUuid)/participants")
        }
    }

    func addGroupParticipants(chatUuid: String, memberUuids: [String]) async throws {
        try await authorized {
            try await client.requestVoid(
                "POST",
                "/api/chats/\(chatUuid)/participants",
                body: AddGroupParticipantsRequest(memberUuids: memberUuids)
            )
        }
    }

    // MARK: - Contacts

    func loadContacts() async throws -> [ContactResponse] {
        try await authorized { try await client.request("GET", "/api/contacts") }
    }

    func addContact(username: String) async throws -> ContactResponse {
        let user: ChatUserResponse = try await authorized {
            try await client.request("GET", "/api/users/by-username/\(username)")
        }
        return try await authorized {
            try await client.request(
                "POST",
                "/api/contacts",
                body: AddContactRequest(contactUserUuid: user.userUuid, contactName: nil)
            )
        }
    }

    // MARK: - Messages

    func loadMessages(chatUuid: String) async throws -> [MessageResponse] {
        let page: PageResponse<MessageResponse> = try await authorized {
            try await client.request(
                "GET",
                "/api/messages/\(chatUuid)",
                query: [
                    URLQueryItem(name: "page", value: "0"),
                    URLQueryItem(name: "size", value: "\(Config.messagePageSize)")
                ]
            )
        }
        return page.content
    }

    func sendMessage(chatUuid: String, text: String) async throws -> MessageResponse {
        try await authorized {
            try await client.request(
                "POST",
                "/api/messages/\(chatUuid)",
                body: SendMessageRequest(text: text, messageType: "TEXT")
            )
        }
    }

    func markMessagesAsRead(chatUuid: String, upToMessageUuid: String) async {
        _ = try? await authorized {
            try await client.requestVoid(
                "POST",
                "/api/messages/\(chatUuid)/read",
                query: [URLQueryItem(name: "upToMessageUuid", value: upToMessageUuid)]
            )
        }
    }

    // MARK: - Profile / avatar

    func currentChatUser() async throws -> ChatUserResponse {
        try await authorized { try await client.request("GET", "/api/users/me") }
    }

    func uploadAvatar(data: Data, fileName: String, mimeType: String) async throws -> String? {
        let response: AvatarResponse = try await authorized {
            try await client.upload(
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
        try await authorized { try await client.requestVoid("DELETE", "/api/users/me/avatar") }
    }

    /// Загружает аватар группы; сервер отвечает относительным путём картинки.
    func uploadChatAvatar(chatUuid: String, data: Data, fileName: String, mimeType: String) async throws -> String? {
        let raw: Data = try await authorized {
            try await client.uploadData(
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
