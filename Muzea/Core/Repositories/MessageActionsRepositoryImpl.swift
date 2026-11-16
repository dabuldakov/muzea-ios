import Foundation

/// Правки, удаление, пересылка и закрепление сообщений.
final class MessageActionsRepositoryImpl: MessageActionsRepository {
    private let auth: ChatAuthorization

    init(auth: ChatAuthorization) {
        self.auth = auth
    }

    func editMessage(messageUuid: String, text: String) async throws -> MessageResponse {
        try await auth.authorized {
            try await auth.client.request(
                "PUT",
                "/api/messages/\(messageUuid)",
                body: EditMessageRequest(text: text)
            )
        }
    }

    func deleteMessage(messageUuid: String) async throws {
        try await auth.authorized {
            try await auth.client.requestVoid("DELETE", "/api/messages/\(messageUuid)")
        }
    }

    func forwardMessage(messageUuid: String, toChatUuid: String) async throws -> MessageResponse {
        try await auth.authorized {
            try await auth.client.request(
                "POST",
                "/api/messages/forward",
                body: ForwardMessageRequest(
                    messageUuid: messageUuid,
                    targetChatUuid: toChatUuid
                )
            )
        }
    }

    /// ⚠ На бэкенде это GET, хотя операция меняет состояние.
    func pinMessage(chatUuid: String, messageUuid: String) async throws {
        try await auth.authorized {
            try await auth.client.requestVoid(
                "GET",
                "/api/messages/\(chatUuid)/pin/\(messageUuid)"
            )
        }
    }

    func unpinMessage(chatUuid: String, messageUuid: String) async throws {
        try await auth.authorized {
            try await auth.client.requestVoid(
                "DELETE",
                "/api/messages/\(chatUuid)/pin/\(messageUuid)"
            )
        }
    }

    func loadPinned(chatUuid: String) async throws -> [MessageResponse] {
        try await auth.authorized {
            try await auth.client.request("GET", "/api/messages/\(chatUuid)/pinned")
        }
    }
}
