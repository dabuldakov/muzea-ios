import Foundation

/// Открывает переписку с контактом: если приватный чат уже существует —
/// возвращает его, иначе создаёт новый. Так повторное нажатие на контакт не
/// плодит дубликаты чатов.
///
/// Раньше эта логика жила прямо в `ContactListViewModel`, из-за чего любой тап
/// по контакту создавал новую переписку.
final class OpenPrivateChatUseCase {
    private let repository: ChatRepository

    init(repository: ChatRepository) {
        self.repository = repository
    }

    func callAsFunction(userUuid: String) async throws -> ChatResponse {
        let existing = try? await repository.findPrivateChatWith(userUuid: userUuid)
        if let existing {
            return existing
        }
        return try await repository.createPrivateChat(userUuid: userUuid)
    }
}
