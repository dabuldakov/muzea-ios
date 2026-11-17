import Foundation

/// Квитанции участников: водяные знаки доставки и прочтения.
final class MessageReceiptRepositoryImpl: MessageReceiptRepository {
    private let auth: ChatAuthorization

    init(auth: ChatAuthorization) {
        self.auth = auth
    }

    func loadReceipts(chatUuid: String) async throws -> [ChatReceipt] {
        let dtos: [ChatReceiptDTO] = try await auth.authorized {
            try await auth.client.request("GET", "/api/chats/\(chatUuid)/receipts")
        }
        return dtos.map { $0.toDomain() }
    }
}
