import Foundation

/// Реализация `MessageRepository`: загрузка, отправка и отметки о прочтении.
final class MessageRepositoryImpl: MessageRepository {
    private let auth: ChatAuthorization
    private let cache: ChatMessagesCache

    init(auth: ChatAuthorization, cache: ChatMessagesCache) {
        self.auth = auth
        self.cache = cache
    }

    func loadMessages(chatUuid: String) async throws -> [ChatMessage] {
        let page: PageResponse<ChatMessageDTO> = try await auth.authorized {
            try await auth.client.request(
                "GET",
                "/api/messages/\(chatUuid)",
                query: [
                    URLQueryItem(name: "page", value: "0"),
                    URLQueryItem(name: "size", value: "\(Config.messagePageSize)")
                ]
            )
        }
        let messages = page.content.map { $0.toDomain() }
        cache.put(chatUuid: chatUuid, list: messages)
        return messages
    }

    func cachedMessages(chatUuid: String) -> [ChatMessage] {
        cache.get(chatUuid: chatUuid)
    }

    func loadMessagesBefore(
        chatUuid: String,
        beforeMessageUuid: String,
        limit: Int
    ) async throws -> [ChatMessage] {
        let list: [ChatMessageDTO] = try await auth.authorized {
            try await auth.client.request(
                "GET",
                "/api/messages/\(chatUuid)/before/\(beforeMessageUuid)",
                query: [URLQueryItem(name: "limit", value: "\(limit)")]
            )
        }
        let messages = list.map { $0.toDomain() }
        cache.prepend(chatUuid: chatUuid, older: messages)
        return messages
    }

    func sendMessage(chatUuid: String, text: String) async throws -> ChatMessage {
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
    ) async throws -> ChatMessage {
        try await sendMessage(
            chatUuid: chatUuid,
            text: text,
            messageType: "TEXT",
            replyToMessageUuid: replyToMessageUuid,
            clientMessageId: clientMessageId,
            attachments: [],
            power: power
        )
    }

    func sendMessage(
        chatUuid: String,
        text: String,
        messageType: String,
        replyToMessageUuid: String?,
        clientMessageId: String?,
        attachments: [String],
        power: Int
    ) async throws -> ChatMessage {
        let dto: ChatMessageDTO = try await auth.authorized {
            try await auth.client.request(
                "POST",
                "/api/messages/\(chatUuid)",
                body: SendMessageRequest(
                    text: text,
                    messageType: messageType,
                    replyToMessageUuid: replyToMessageUuid,
                    clientMessageId: clientMessageId,
                    power: power > 0 ? min(power, 100) : nil,
                    attachments: attachments.isEmpty ? nil : attachments
                )
            )
        }
        return dto.toDomain()
    }

    func sendGif(
        chatUuid: String,
        gif: Gif,
        replyToMessageUuid: String?
    ) async throws -> ChatMessage {
        let dto: ChatMessageDTO = try await auth.authorized {
            try await auth.client.request(
                "POST",
                "/api/messages/\(chatUuid)",
                body: SendMessageRequest(
                    text: "",
                    messageType: "GIF",
                    replyToMessageUuid: replyToMessageUuid,
                    clientMessageId: nil,
                    power: nil,
                    attachments: nil,
                    gif: GifPayload(
                        provider: gif.provider,
                        providerGifId: gif.providerGifId,
                        title: gif.title,
                        url: gif.url,
                        previewUrl: gif.previewUrl,
                        mp4Url: gif.mp4Url,
                        width: gif.width,
                        height: gif.height
                    )
                )
            )
        }
        return dto.toDomain()
    }

    func loadMessagesAfter(chatUuid: String, timestamp: String) async throws -> [ChatMessage] {
        let dtos: [ChatMessageDTO] = try await auth.authorized {
            try await auth.client.request(
                "GET",
                "/api/messages/\(chatUuid)/after/\(Self.pathTimestamp(timestamp))"
            )
        }
        let messages = dtos.map { $0.toDomain() }
        cache.appendNewer(chatUuid: chatUuid, newer: messages)
        return messages
    }

    func loadMessagesUpdated(chatUuid: String, timestamp: String) async throws -> [ChatMessage] {
        let dtos: [ChatMessageDTO] = try await auth.authorized {
            try await auth.client.request(
                "GET",
                "/api/messages/\(chatUuid)/updated/\(Self.pathTimestamp(timestamp))"
            )
        }
        let messages = dtos.map { $0.toDomain() }
        cache.appendNewer(chatUuid: chatUuid, newer: messages)
        return messages
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
