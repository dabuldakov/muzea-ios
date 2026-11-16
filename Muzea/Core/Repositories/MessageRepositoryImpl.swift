import Foundation

/// Реализация `MessageRepository`: загрузка, отправка и отметки о прочтении.
final class MessageRepositoryImpl: MessageRepository {
    private let auth: ChatAuthorization
    private let cache: ChatMessagesCache

    init(auth: ChatAuthorization, cache: ChatMessagesCache) {
        self.auth = auth
        self.cache = cache
    }

    func loadMessages(chatUuid: String) async throws -> [MessageResponse] {
        let page: PageResponse<MessageResponse> = try await auth.authorized {
            try await auth.client.request(
                "GET",
                "/api/messages/\(chatUuid)",
                query: [
                    URLQueryItem(name: "page", value: "0"),
                    URLQueryItem(name: "size", value: "\(Config.messagePageSize)")
                ]
            )
        }
        cache.put(chatUuid: chatUuid, list: page.content)
        return page.content
    }

    func cachedMessages(chatUuid: String) -> [MessageResponse] {
        cache.get(chatUuid: chatUuid)
    }

    func sendMessage(chatUuid: String, text: String) async throws -> MessageResponse {
        try await sendMessage(
            chatUuid: chatUuid,
            text: text,
            replyToMessageUuid: nil,
            clientMessageId: nil,
            power: 0
        )
    }

    func sendMessage(
        chatUuid: String,
        text: String,
        replyToMessageUuid: String?,
        clientMessageId: String?,
        power: Int
    ) async throws -> MessageResponse {
        try await auth.authorized {
            try await auth.client.request(
                "POST",
                "/api/messages/\(chatUuid)",
                body: SendMessageRequest(
                    text: text,
                    messageType: "TEXT",
                    replyToMessageUuid: replyToMessageUuid,
                    clientMessageId: clientMessageId,
                    power: power > 0 ? min(power, 100) : nil
                )
            )
        }
    }

    func loadMessagesAfter(chatUuid: String, timestamp: String) async throws -> [MessageResponse] {
        try await auth.authorized {
            try await auth.client.request(
                "GET",
                "/api/messages/\(chatUuid)/after/\(Self.pathTimestamp(timestamp))"
            )
        }
    }

    func loadMessagesUpdated(chatUuid: String, timestamp: String) async throws -> [MessageResponse] {
        try await auth.authorized {
            try await auth.client.request(
                "GET",
                "/api/messages/\(chatUuid)/updated/\(Self.pathTimestamp(timestamp))"
            )
        }
    }

    func markMessagesAsRead(chatUuid: String, upToMessageUuid: String) async {
        _ = try? await auth.authorized {
            try await auth.client.requestVoid(
                "POST",
                "/api/messages/\(chatUuid)/read",
                query: [URLQueryItem(name: "upToMessageUuid", value: upToMessageUuid)]
            )
        }
    }

    func markMessagesAsDelivered(chatUuid: String, upToMessageUuid: String) async {
        _ = try? await auth.authorized {
            try await auth.client.requestVoid(
                "POST",
                "/api/messages/\(chatUuid)/delivered",
                query: [URLQueryItem(name: "upToMessageUuid", value: upToMessageUuid)]
            )
        }
    }

    /// Timestamp попадает в путь, а не в query: экранируем только то, что
    /// действительно ломает URL. Двоеточия в ISO-строке допустимы в пути.
    private static func pathTimestamp(_ timestamp: String) -> String {
        timestamp.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? timestamp
    }
}
