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
    /// Отправка с ответом и ключом идемпотентности.
    func sendMessage(
        chatUuid: String,
        text: String,
        replyToMessageUuid: String?,
        clientMessageId: String?
    ) async throws -> MessageResponse
    /// Инкрементальная синхронизация: только новые сообщения после timestamp.
    func loadMessagesAfter(chatUuid: String, timestamp: String) async throws -> [MessageResponse]
    /// Окно правок/закрепов. Удаления сюда не попадают — нужен полный refresh.
    func loadMessagesUpdated(chatUuid: String, timestamp: String) async throws -> [MessageResponse]
    func markMessagesAsRead(chatUuid: String, upToMessageUuid: String) async
    func markMessagesAsDelivered(chatUuid: String, upToMessageUuid: String) async
}

/// Действия над уже отправленными сообщениями. Отдельный контракт, чтобы
/// экран не тянул за собой god-репозиторий.
protocol MessageActionsRepository {
    func editMessage(messageUuid: String, text: String) async throws -> MessageResponse
    func deleteMessage(messageUuid: String) async throws
    func forwardMessage(messageUuid: String, toChatUuid: String) async throws -> MessageResponse
    func pinMessage(chatUuid: String, messageUuid: String) async throws
    func unpinMessage(chatUuid: String, messageUuid: String) async throws
    func loadPinned(chatUuid: String) async throws -> [MessageResponse]
}

protocol MessageReactionRepository {
    /// Ставит или снимает реакцию; возвращает свежую сводку по сообщению.
    func toggleReaction(messageUuid: String, emoji: String) async throws -> [MessageReactionResponse]
}

protocol MessageReceiptRepository {
    func loadReceipts(chatUuid: String) async throws -> [ChatReceiptResponse]
}

/// Черновики по чатам. Хранятся локально и не отправляются автоматически.
protocol ChatDraftStore {
    func draft(chatUuid: String) -> String?
    func save(chatUuid: String, text: String?)
    func clear(chatUuid: String)
    func clearAll()
}

extension MessageRepository {
    /// Запасная реализация для тест-дублей: старый send без reply/идемпотентности.
    func sendMessage(
        chatUuid: String,
        text: String,
        replyToMessageUuid: String?,
        clientMessageId: String?
    ) async throws -> MessageResponse {
        try await sendMessage(chatUuid: chatUuid, text: text)
    }

    func loadMessagesAfter(chatUuid: String, timestamp: String) async throws -> [MessageResponse] {
        try await loadMessages(chatUuid: chatUuid)
    }

    func loadMessagesUpdated(chatUuid: String, timestamp: String) async throws -> [MessageResponse] {
        []
    }

    func markMessagesAsDelivered(chatUuid: String, upToMessageUuid: String) async {}
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
    func totalUnreadCount() async throws -> Int64
}
