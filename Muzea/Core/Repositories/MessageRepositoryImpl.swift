import Foundation

/// Реализация `MessageRepository`: загрузка, отправка и отметка о прочтении.
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
        try await auth.authorized {
            try await auth.client.request(
                "POST",
                "/api/messages/\(chatUuid)",
                body: SendMessageRequest(text: text, messageType: "TEXT")
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
}
