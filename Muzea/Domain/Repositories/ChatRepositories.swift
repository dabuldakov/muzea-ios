import Foundation

/// Контракты чат-фичи. UI и ViewModel зависят только от этих протоколов,
/// реализации живут в data-слое и собираются в `AppContainer`.
///
/// Каждый протокол отвечает за одну зону ответственности (SRP): диалоги,
/// сообщения, контакты, аватары и серверную сессию — как на Android после
/// разбиения god-репозитория.

protocol ChatRepository {
    func loadChats() async throws -> [Chat]
    func cachedChats() -> [Chat]
    func loadChatParticipants(chatUuid: String) async throws -> [ChatParticipant]
    func createPrivateChat(userUuid: String) async throws -> Chat
    func findPrivateChatWith(userUuid: String) async throws -> Chat?
    func createGroupChat(title: String, memberUuids: [String]) async throws -> Chat
    func addGroupParticipants(chatUuid: String, memberUuids: [String]) async throws
}

protocol MessageRepository {
    func loadMessages(chatUuid: String) async throws -> [ChatMessage]
    func cachedMessages(chatUuid: String) -> [ChatMessage]
    func sendMessage(chatUuid: String, text: String) async throws -> ChatMessage
    /// Отправка с ответом, ключом идемпотентности и зарядом.
    func sendMessage(
        chatUuid: String,
        text: String,
        replyToMessageUuid: String?,
        clientMessageId: String?,
        power: Int
    ) async throws -> ChatMessage
    /// Отправка медиа: тип сообщения и UUID вложений.
    func sendMessage(
        chatUuid: String,
        text: String,
        messageType: String,
        replyToMessageUuid: String?,
        clientMessageId: String?,
        attachments: [String],
        power: Int
    ) async throws -> ChatMessage
    /// GIF: провайдер и метаданные, без idempotency-ключа (как на Android).
    func sendGif(
        chatUuid: String,
        gif: Gif,
        replyToMessageUuid: String?
    ) async throws -> ChatMessage
    /// Инкрементальная синхронизация: только новые сообщения после timestamp.
    func loadMessagesAfter(chatUuid: String, timestamp: String) async throws -> [ChatMessage]
    /// Окно правок/закрепов. Удаления сюда не попадают — нужен полный refresh.
    func loadMessagesUpdated(chatUuid: String, timestamp: String) async throws -> [ChatMessage]
    func markMessagesAsRead(chatUuid: String, upToMessageUuid: String) async
    func markMessagesAsDelivered(chatUuid: String, upToMessageUuid: String) async
}

/// Действия над уже отправленными сообщениями. Отдельный контракт, чтобы
/// экран не тянул за собой god-репозиторий.
protocol MessageActionsRepository {
    func editMessage(messageUuid: String, text: String) async throws -> ChatMessage
    func deleteMessage(messageUuid: String) async throws
    func forwardMessage(messageUuid: String, toChatUuid: String) async throws -> ChatMessage
    func pinMessage(chatUuid: String, messageUuid: String) async throws
    func unpinMessage(chatUuid: String, messageUuid: String) async throws
    func loadPinned(chatUuid: String) async throws -> [ChatMessage]
}

protocol MessageReactionRepository {
    /// Ставит или снимает реакцию; возвращает свежую сводку по сообщению.
    func toggleReaction(messageUuid: String, emoji: String) async throws -> [MessageReaction]
}

protocol MessageReceiptRepository {
    func loadReceipts(chatUuid: String) async throws -> [ChatReceipt]
}

/// Точные отметки доставки/прочтения конкретного сообщения. В отличие от
/// watermark-квитанций, для старых сообщений не дают ложную дату.
protocol MessageStatusRepository {
    func loadMessageStatuses(chatUuid: String, messageUuid: String) async throws -> [MessageStatus]
}

/// Жалобы и блокировки в чате.
protocol ModerationRepository {
    func report(messageUuid: String, reason: String, comment: String?) async throws
    func block(userUuid: String, reason: String?) async throws
}

/// Вложения: загрузка orphan-файла и скачивание через бэкенд.
protocol AttachmentRepository {
    func upload(
        chatUuid: String,
        data: Data,
        fileName: String,
        mimeType: String,
        kind: AttachmentKind,
        thumbnail: Data?,
        width: Int?,
        height: Int?,
        duration: Int?
    ) async throws -> ChatAttachment
    func download(attachmentUuid: String) async throws -> Data
    /// Превью для пузыря: оригинал для изображений, миниатюра для видео.
    func preview(attachmentUuid: String) async throws -> Data
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
        clientMessageId: String?,
        power: Int
    ) async throws -> ChatMessage {
        try await sendMessage(chatUuid: chatUuid, text: text)
    }

    /// Запасная реализация для тест-дублей: медиа без вложений.
    func sendMessage(
        chatUuid: String,
        text: String,
        messageType: String,
        replyToMessageUuid: String?,
        clientMessageId: String?,
        attachments: [String],
        power: Int
    ) async throws -> ChatMessage {
        try await sendMessage(
            chatUuid: chatUuid,
            text: text,
            replyToMessageUuid: replyToMessageUuid,
            clientMessageId: clientMessageId,
            power: power
        )
    }

    /// Запасная реализация для тест-дублей.
    func sendGif(
        chatUuid: String,
        gif: Gif,
        replyToMessageUuid: String?
    ) async throws -> ChatMessage {
        try await sendMessage(chatUuid: chatUuid, text: "")
    }

    func loadMessagesAfter(chatUuid: String, timestamp: String) async throws -> [ChatMessage] {
        try await loadMessages(chatUuid: chatUuid)
    }

    func loadMessagesUpdated(chatUuid: String, timestamp: String) async throws -> [ChatMessage] {
        []
    }

    func markMessagesAsDelivered(chatUuid: String, upToMessageUuid: String) async {}
}

protocol ContactRepository {
    func loadContacts() async throws -> [Contact]
    func addContact(username: String) async throws -> Contact
    /// Пакетный статус присутствия. Ошибка отдельного чанка не срывает остальные.
    func loadPresence(userUuids: [String]) async -> [String: Presence]
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
