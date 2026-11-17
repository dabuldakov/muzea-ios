import Foundation

/// Точные статусы участников по конкретному сообщению.
final class MessageStatusRepositoryImpl: MessageStatusRepository {
    private let auth: ChatAuthorization

    init(auth: ChatAuthorization) {
        self.auth = auth
    }

    func loadMessageStatuses(
        chatUuid: String,
        messageUuid: String
    ) async throws -> [MessageStatus] {
        let dtos: [MessageStatusDTO] = try await auth.authorized {
            try await auth.client.request(
                "GET",
                "/api/messages/\(chatUuid)/status/\(messageUuid)"
            )
        }
        return dtos.map { $0.toDomain() }
    }
}
