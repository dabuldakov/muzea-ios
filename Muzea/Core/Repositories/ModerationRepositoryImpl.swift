import Foundation

/// Жалобы на сообщения и блокировка пользователей в чате.
final class ModerationRepositoryImpl: ModerationRepository {
    private let auth: ChatAuthorization

    init(auth: ChatAuthorization) {
        self.auth = auth
    }

    func report(messageUuid: String, reason: String, comment: String?) async throws {
        try await auth.authorized {
            try await auth.client.requestVoid(
                "POST",
                "/api/reports",
                body: CreateReportRequest(
                    contentType: "MESSAGE",
                    contentUuid: messageUuid,
                    reason: reason,
                    comment: comment
                )
            )
        }
    }

    func block(userUuid: String, reason: String?) async throws {
        try await auth.authorized {
            try await auth.client.requestVoid(
                "POST",
                "/api/blocked",
                body: BlockUserRequest(blockUserUuid: userUuid, reason: reason)
            )
        }
    }
}
