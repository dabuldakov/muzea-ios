import Foundation

/// Контракты чат-фичи. UI и ViewModel зависят только от этих протоколов,
/// реализации живут в data-слое и собираются в `AppContainer`.
///
/// Каждый протокол отвечает за одну зону ответственности (SRP): диалоги,
/// сообщения, контакты, аватары и серверную сессию — как на Android после
/// разбиения god-репозитория.

protocol ChatRepository {
    func loadChats() async throws -> [ChatResponse]
    func cachedChats() -> [ChatResponse]
    func loadChatParticipants(chatUuid: String) async throws -> [ChatParticipantResponse]
    func createPrivateChat(userUuid: String) async throws -> ChatResponse
    func findPrivateChatWith(userUuid: String) async throws -> ChatResponse?
    func createGroupChat(title: String, memberUuids: [String]) async throws -> ChatResponse
    func addGroupParticipants(chatUuid: String, memberUuids: [String]) async throws
}

protocol MessageRepository {
    func loadMessages(chatUuid: String) async throws -> [MessageResponse]
    func cachedMessages(chatUuid: String) -> [MessageResponse]
    func sendMessage(chatUuid: String, text: String) async throws -> MessageResponse
    func markMessagesAsRead(chatUuid: String, upToMessageUuid: String) async
}

protocol ContactRepository {
    func loadContacts() async throws -> [ContactResponse]
    func addContact(username: String) async throws -> ContactResponse
    /// Пакетный статус присутствия. Ошибка отдельного чанка не срывает остальные.
    func loadPresence(userUuids: [String]) async -> [String: PresenceResponse]
}

protocol AvatarRepository {
    func loadAvatar() async throws -> String?
    func uploadAvatar(data: Data, fileName: String, mimeType: String) async throws -> String?
    func deleteAvatar() async throws
    func uploadChatAvatar(chatUuid: String, data: Data, fileName: String, mimeType: String) async throws -> String?
}

protocol ChatSessionRepository {
    func deleteAccount() async throws
    func sendHeartbeat() async -> Bool
    func logout() async -> Bool
    func totalUnreadCount() async throws -> Int64
}
