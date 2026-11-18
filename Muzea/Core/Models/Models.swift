import Foundation

// MARK: - Makeup (main backend, :8085)

struct UpdateUserRequest: Encodable {
    let fullName: String?
    let email: String?
    let enabled: Bool
}

struct UserDTO: Decodable {
    let id: Int64
    let userName: String
    /// В makeup email больше не хранится — он живёт в auth-service.
    let email: String?
    let fullName: String?
    let avatarUrl: String?
    let role: String
    let createdAt: String?
    let enabled: Bool?
}

struct NewsDTO: Decodable, Identifiable, Hashable {
    let id: Int64
    let title: String
    let content: String
    let imageUrl: String?
    let relatedVideo: VideoDTO?
    let author: String
    let publishedAt: String
}

struct NewsCreateResponse: Decodable {
    let id: Int64
}

struct VideoDTO: Decodable, Identifiable, Hashable {
    let id: Int64
    let title: String
    let description: String?
    let url: String
    let thumbnailUrl: String?
    let fileSize: Int64?
    // Бэкенд отдаёт длительность числом секунд (durationSeconds), а не строкой
    // duration; строка не приходила никогда. likedByMe — лайк текущего
    // пользователя, тоже присутствует в ответе.
    let durationSeconds: Int?
    let views: Int
    let likes: Int?
    let likedByMe: Bool?
    let uploadedBy: String
    let uploadedAt: String

    var fullThumbnailURL: URL? {
        guard let thumbnailUrl, !thumbnailUrl.isEmpty else { return nil }
        return ImageURL.makeup(thumbnailUrl)
    }

    var fullVideoURL: URL? {
        if url.hasPrefix("http") { return URL(string: url) }
        return ImageURL.makeup(url)
    }
}

struct PageResponse<T: Decodable>: Decodable {
    let content: [T]
    let empty: Bool?
    let first: Bool?
    let last: Bool?
    let number: Int?
    let numberOfElements: Int?
    let size: Int?
    let totalElements: Int64?
    let totalPages: Int?
}

// MARK: - Chat backend (:8086)

struct ChatAuthResponse: Decodable {
    let token: String
    let refreshToken: String?
    let userUuid: String?
    let username: String?
    let email: String?
    let avatarUrl: String?
}

struct ChatLoginRequest: Encodable {
    let username: String
    let password: String
    let deviceId: String?
    let deviceName: String?
    let deviceType: String?
}

struct ChatRegisterRequest: Encodable {
    let username: String
    let email: String
    let password: String
    let deviceId: String?
    let deviceName: String?
    let deviceType: String?
}

struct ChatUserResponse: Decodable {
    let userUuid: String
    let username: String?
    let email: String?
    let firstName: String?
    let lastName: String?
    let fullName: String?
    let avatarUrl: String?
    let isOnline: Bool?

    // Бэкенд отдаёт ключ "online", а не "isOnline": без маппинга флаг всегда
    // оставался бы nil, и «в сети» не горело ни у кого.
    private enum CodingKeys: String, CodingKey {
        case userUuid, username, email, firstName, lastName, fullName, avatarUrl
        case isOnline = "online"
    }
}

struct Chat: Identifiable, Hashable {
    var id: String { chatUuid }
    let chatUuid: String
    let chatType: String?
    let title: String?
    let avatarUrl: String?
    let createdAt: String?
    let updatedAt: String?
    let participantCount: Int64?
    let lastMessage: MessagePreview?
    let unreadCount: Int64?
    /// Личный чат с удалённым пользователем: имя скрыто, отправка запрещена.
    var peerDeleted: Bool? = nil
}

struct MessagePreview: Hashable {
    let messageUuid: String?
    let text: String?
    let senderId: Int64?
    let senderName: String?
    let createdAt: String?
}

struct Contact: Identifiable, Hashable {
    var id: String { contactUuid }
    let contactUuid: String
    let contactUserId: Int64?
    let contactUserUuid: String?
    let username: String?
    let firstName: String?
    let lastName: String?
    let fullName: String?
    let avatarUrl: String?
    let contactName: String?
    let isOnline: Bool
    let lastSeenAt: String?
    let addedAt: String?

    var displayName: String { contactName ?? fullName ?? username ?? "Contact" }

    // Ключ присутствия приходит как "online" (ContactDto помечен @JsonProperty).
    // Со старым "isOnline" декодирование падало на обязательном Bool.
    private enum CodingKeys: String, CodingKey {
        case contactUuid, contactUserId, contactUserUuid, username, firstName, lastName
        case fullName, avatarUrl, contactName, lastSeenAt, addedAt
        case isOnline = "online"
    }

    /// Копия контакта с обновлённым присутствием. `lastSeenAt` сохраняется,
    /// если сервер не прислал новое значение.
    func replacingPresence(online: Bool, lastSeenAt: String?) -> Contact {
        Contact(
            contactUuid: contactUuid,
            contactUserId: contactUserId,
            contactUserUuid: contactUserUuid,
            username: username,
            firstName: firstName,
            lastName: lastName,
            fullName: fullName,
            avatarUrl: avatarUrl,
            contactName: contactName,
            isOnline: online,
            lastSeenAt: lastSeenAt ?? self.lastSeenAt,
            addedAt: addedAt
        )
    }
}

/// Статус присутствия одного пользователя из `GET /api/presence`.
///
/// `online` вычислен сервером по TTL от последней активности, а не прочитан
/// из флага в БД. `lastSeenAt` приходит, пока пользователь хоть раз был в сети.
struct Presence {
    let userUuid: String
    let online: Bool
    let lastSeenAt: String?
}

struct ChatMessage: Identifiable, Hashable {
    var id: String { messageUuid }
    let messageUuid: String
    /// Глобальный монотонный id сервера. У локальных сообщений — nil; по нему
    /// сравниваются водяные знаки прочтения и доставки.
    var messageId: Int64? = nil
    let chatUuid: String?
    let senderId: Int64?
    let senderUuid: String?
    let senderName: String?
    let senderAvatar: String?
    let text: String?
    let messageType: String?
    let replyToMessageUuid: String?
    var forwardedFromMessageUuid: String? = nil
    var forwardedFromUserUuid: String? = nil
    let isEdited: Bool?
    let isDeleted: Bool?
    let isPinned: Bool?
    let createdAt: String?
    let updatedAt: String?
    /// Сводка реакций. Сервер всегда отдаёт массив, но в старых ответах его нет.
    var reactions: [MessageReaction]? = nil
    /// Сила «заряда» отправителя, 0...100 (0 — обычное сообщение).
    var power: Int? = nil
    /// Вложения сообщения: фото, видео, аудио, документы, GIF.
    var attachments: [ChatAttachment]? = nil
    /// Автор удалён: имя/аватар скрываются, показываем «Удалённый пользователь».
    var senderDeleted: Bool? = nil

    /// Копия сообщения с другим идентификатором. Нужна, чтобы подменить
    /// оптимистичный локальный пузырь серверным эхом, сохранив локальный UUID
    /// (иначе список перерисовывается и мигает) — аналог Kotlin `copy`.
    func withMessageUuid(_ uuid: String) -> ChatMessage {
        replacing(messageUuid: uuid)
    }

    /// Полная копия с точечными изменениями (аналог Kotlin `copy`): UI-слой
    /// обновляет флаги/реакции, не теряя серверные поля.
    func replacing(
        messageUuid: String? = nil,
        messageId: Int64? = nil,
        text: String? = nil,
        messageType: String? = nil,
        replyToMessageUuid: String? = nil,
        isEdited: Bool? = nil,
        isDeleted: Bool? = nil,
        isPinned: Bool? = nil,
        reactions: [MessageReaction]? = nil,
        power: Int? = nil,
        attachments: [ChatAttachment]? = nil,
        senderDeleted: Bool? = nil
    ) -> ChatMessage {
        ChatMessage(
            messageUuid: messageUuid ?? self.messageUuid,
            messageId: messageId ?? self.messageId,
            chatUuid: chatUuid,
            senderId: senderId,
            senderUuid: senderUuid,
            senderName: senderName,
            senderAvatar: senderAvatar,
            text: text ?? self.text,
            messageType: messageType ?? self.messageType,
            replyToMessageUuid: replyToMessageUuid ?? self.replyToMessageUuid,
            forwardedFromMessageUuid: forwardedFromMessageUuid,
            forwardedFromUserUuid: forwardedFromUserUuid,
            isEdited: isEdited ?? self.isEdited,
            isDeleted: isDeleted ?? self.isDeleted,
            isPinned: isPinned ?? self.isPinned,
            createdAt: createdAt,
            updatedAt: updatedAt,
            reactions: reactions ?? self.reactions,
            power: power ?? self.power,
            attachments: attachments ?? self.attachments,
            senderDeleted: senderDeleted ?? self.senderDeleted
        )
    }
}

/// Вложение сообщения. `fileUrl` — ключ в MinIO, а не готовый URL; скачивание
/// идёт через `/api/attachments/{attachmentUuid}`.
struct ChatAttachment: Codable, Hashable, Identifiable {
    var id: String { attachmentUuid ?? fileUrl ?? fileName ?? "attachment" }

    let attachmentUuid: String?
    let fileName: String?
    let fileUrl: String?
    let thumbnailUrl: String?
    let mp4Url: String?
    let fileSize: Int64?
    let mimeType: String?
    let type: String?
    let width: Int?
    let height: Int?
    let duration: Int?
    let gifKey: String?
}

struct MessageReaction: Hashable {
    let emoji: String
    let count: Int
    let mine: Bool
    let users: [ReactionUser]?
}

struct ReactionUser: Hashable {
    let userUuid: String?
    let at: String?
}

/// Квитанция участника: докуда его устройство доставило и докуда прочитало.
/// Сравнивается с `ChatMessage.messageId`.
struct ChatReceipt: Hashable {
    let userUuid: String?
    let username: String?
    let fullName: String?
    let avatarUrl: String?
    let joinedAt: String?
    let lastDeliveredMessageId: Int64?
    let lastDeliveredAt: String?
    let lastReadMessageId: Int64?
    let lastReadAt: String?

    var displayName: String { fullName ?? username ?? L10n.participant }
}

/// Точный статус участника для конкретного сообщения
/// (`GET /api/messages/{chatUuid}/status/{messageUuid}`).
struct MessageStatus: Hashable {
    let userId: Int64?
    let userUuid: String?
    let status: String?
    let deliveredAt: String?
    let readAt: String?
}

struct CreateReportRequest: Encodable {
    let contentType: String
    let contentUuid: String
    let reason: String
    let comment: String?
}

struct BlockUserRequest: Encodable {
    let blockUserUuid: String
    let reason: String?
}

struct CreateContentReportRequest: Encodable {
    let contentType: String
    let contentId: Int64
    let reason: String
    let comment: String?
}

/// Статус собственного сообщения. Отправляется в UI как галочки.
enum MessageDeliveryStatus: String, Hashable {
    case sending
    case failed
    case sent
    case delivered
    case read
}

struct UnreadCountResponse: Decodable {
    let count: Int64
}

struct AvatarResponse: Decodable {
    let avatarUrl: String?
}

struct ChatParticipant: Identifiable, Hashable {
    var id: String { userUuid ?? "\(userId ?? 0)-\(username ?? "")" }
    let userUuid: String?
    let userId: Int64?
    let username: String?
    let firstName: String?
    let lastName: String?
    let fullName: String?
    let nickname: String?
    let avatarUrl: String?
    let role: String?
    let online: Bool?
    let lastSeenAt: String?
    let joinedAt: String?

    var displayName: String { fullName ?? username ?? "Participant" }
}

struct AddContactRequest: Encodable {
    let contactUserUuid: String
    let contactName: String?
}

struct CreatePrivateChatRequest: Encodable {
    let otherUserUuid: String
}

struct CreateGroupChatRequest: Encodable {
    let title: String
    let memberUuids: [String]
}

struct AddGroupParticipantsRequest: Encodable {
    let memberUuids: [String]
}

struct SendMessageRequest: Encodable {
    let text: String
    let messageType: String
    /// Сообщение, на которое отвечаем. Сервер ждёт реальный uuid.
    var replyToMessageUuid: String? = nil
    /// Идемпотентность текстовых отправок: повтор с тем же id не создаёт дубль.
    var clientMessageId: String? = nil
    /// Сила заряда кнопки отправки, 0...100.
    var power: Int? = nil
    /// UUID загруженных вложений (до 10).
    var attachments: [String]? = nil
    /// Метаданные GIF: поиск делает клиент у Klipy.
    var gif: GifPayload? = nil
}

struct GifPayload: Encodable {
    let provider: String
    let providerGifId: String
    let title: String?
    let url: String
    let previewUrl: String?
    let mp4Url: String?
    let width: Int?
    let height: Int?
}

/// Гифка из нашего API («Мои»/«Этот чат»).
struct GifDTO: Decodable {
    let gifUuid: String?
    let provider: String
    let providerGifId: String
    let title: String?
    let url: String
    let previewUrl: String?
    let mp4Url: String?
    let width: Int?
    let height: Int?

    func toDomain() -> Gif {
        Gif(
            provider: provider,
            providerGifId: providerGifId,
            title: title,
            url: AttachmentURLResolver.absolute(url, base: Config.chatBaseURL)?.absoluteString ?? url,
            previewUrl: AttachmentURLResolver.absolute(previewUrl, base: Config.chatBaseURL)?.absoluteString,
            mp4Url: AttachmentURLResolver.absolute(mp4Url, base: Config.chatBaseURL)?.absoluteString,
            width: width,
            height: height,
            gifKey: gifUuid
        )
    }
}

struct EditMessageRequest: Encodable {
    let text: String
}

struct ForwardMessageRequest: Encodable {
    let messageUuid: String
    let targetChatUuid: String
}

struct ReactionRequest: Encodable {
    let emoji: String
}

struct FcmTokenRequest: Encodable {
    let token: String
    let deviceId: String?
}
