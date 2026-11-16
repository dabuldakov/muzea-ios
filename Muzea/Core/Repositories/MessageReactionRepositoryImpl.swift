import Foundation

/// Реакции на сообщения. Сервер отдаёт агрегированную сводку после toggle.
final class MessageReactionRepositoryImpl: MessageReactionRepository {
    private let auth: ChatAuthorization

    init(auth: ChatAuthorization) {
        self.auth = auth
    }

    func toggleReaction(messageUuid: String, emoji: String) async throws -> [MessageReactionResponse] {
        try await auth.authorized {
            try await auth.client.request(
                "POST",
                "/api/messages/\(messageUuid)/reactions",
                body: ReactionRequest(emoji: emoji)
            )
        }
    }
}
