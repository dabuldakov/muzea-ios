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

    // MARK: - Presence

    /// Heartbeat «я на переднем плане». Тихий метод: ошибку показывать нечего,
    /// упавший удар значит лишь «статус обновится чуть позже», а окно TTL
    /// намеренно шире интервала. Возвращает признак успеха.
    func sendHeartbeat() async -> Bool {
        guard await auth.ensureAuthenticated() else { return false }
        do {
            try await client.requestVoid("POST", "/api/presence/heartbeat")
            return true
        } catch {
            return false
        }
    }

    /// Пакетный статус присутствия по UUID.
    ///
    /// Сервер ограничивает размер пачки, поэтому список режется на чанки, а
    /// ответы склеиваются: иначе запрос на 300 контактов упал бы с 400. Пустой
    /// вход возвращает пустой результат без обращения к сети. Ошибка отдельного
    /// чанка не срывает остальные — частичный результат лучше пустого.
    func loadPresence(userUuids: [String]) async -> [String: PresenceResponse] {
        var seen = Set<String>()
        let wanted = userUuids.filter {
            let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && seen.insert(trimmed).inserted
        }
        guard !wanted.isEmpty else { return [:] }

        var result: [String: PresenceResponse] = [:]
        var index = 0
        while index < wanted.count {
            let end = min(index + Config.presenceBatchSize, wanted.count)
            let chunk = Array(wanted[index..<end])
            defer { index = end }

            do {
                let presence: [PresenceResponse] = try await authorized {
                    try await client.request(
                        "GET",
                        "/api/presence",
                        query: chunk.map { URLQueryItem(name: "userUuids", value: $0) }
                    )
                }
                for item in presence { result[item.userUuid] = item }
            } catch {
                // Пропускаем чанк: остальные контакты всё равно обновятся.
            }
        }
        return result
    }

    /// Серверный разлогин, обязательный до очистки локального токена: пока
    /// сессия жива, сервер считает пользователя онлайн, и его статус «залипнет»
    /// у чужих контактов. Сбою сети разлогин не мешает — TTL догасит сессию.
    func logout() async -> Bool {
        guard await auth.ensureAuthenticated() else { return true }
        do {
            try await client.requestVoid("POST", "/api/auth/logout")
            return true
        } catch {
            return true
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

    /// Полное удаление аккаунта на чат-сервере вместе с сообщениями, контактами,
    /// вложениями и FCM-токенами.
    ///
    /// Намеренно обходится без повторной авторизации: сервер отвечает 401 после
    /// удаления, а перерегистрация тут же создала бы аккаунт заново. 401 и 404
    /// считаются успехом.
    func deleteAccount() async throws {
        guard await auth.ensureAuthenticated() else { throw APIError.unauthorized }
        do {
            try await client.requestVoid("DELETE", "/api/users/me")
        } catch APIError.unauthorized {
            // HTTPClient отдаёт 401 как .unauthorized, а не .server(401, ...).
            return
        } catch APIError.server(let code, _) where code == 404 {
            return
        }
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
