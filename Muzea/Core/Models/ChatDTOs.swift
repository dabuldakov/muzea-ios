import Foundation

// MARK: - Wire DTOs (chat-service)
//
// Эти структуры повторяют JSON один в один и используются только сетевым
// слоем и контрактными тестами. UI/ViewModel работают с доменными моделями
// (`Chat`, `ChatMessage`, `ChatAttachment`, ...), как на Android.

struct ChatDTO: Decodable {
    let chatUuid: String
    let chatType: String?
    let title: String?
    let avatarUrl: String?
    let createdAt: String?
    let updatedAt: String?
    let participantCount: Int64?
    let lastMessage: MessagePreviewDTO?
    let unreadCount: Int64?
    let peerDeleted: Bool?

    func toDomain() -> Chat {
        Chat(
            chatUuid: chatUuid,
            chatType: chatType,
            title: title,
            avatarUrl: avatarUrl,
            createdAt: createdAt,
            updatedAt: updatedAt,
            participantCount: participantCount,
            lastMessage: lastMessage?.toDomain(),
            unreadCount: unreadCount,
            peerDeleted: peerDeleted
        )
    }
}

struct MessagePreviewDTO: Decodable {
    let messageUuid: String?
    let text: String?
    let senderId: Int64?
    let senderName: String?
    let createdAt: String?

    func toDomain() -> MessagePreview {
        MessagePreview(
            messageUuid: messageUuid,
            text: text,
            senderId: senderId,
            senderName: senderName,
            createdAt: createdAt
        )
    }
}

struct ChatMessageDTO: Decodable {
    let messageUuid: String
    let messageId: Int64?
    let chatUuid: String?
    let senderId: Int64?
    let senderUuid: String?
    let senderName: String?
    let senderAvatar: String?
    let text: String?
    let messageType: String?
    let replyToMessageUuid: String?
    let forwardedFromMessageUuid: String?
    let forwardedFromUserUuid: String?
    let isEdited: Bool?
    let isDeleted: Bool?
    let isPinned: Bool?
    let createdAt: String?
    let updatedAt: String?
    let reactions: [MessageReactionDTO]?
    let power: Int?
    let attachments: [ChatAttachmentDTO]?
    let senderDeleted: Bool?

    func toDomain() -> ChatMessage {
        ChatMessage(
            messageUuid: messageUuid,
            messageId: messageId,
            chatUuid: chatUuid,
            senderId: senderId,
            senderUuid: senderUuid,
            senderName: senderName,
            senderAvatar: senderAvatar,
            text: text,
            messageType: messageType,
            replyToMessageUuid: replyToMessageUuid,
            forwardedFromMessageUuid: forwardedFromMessageUuid,
            forwardedFromUserUuid: forwardedFromUserUuid,
            isEdited: isEdited,
            isDeleted: isDeleted,
            isPinned: isPinned,
            createdAt: createdAt,
            updatedAt: updatedAt,
            reactions: reactions?.map { $0.toDomain() },
            power: power,
            attachments: attachments?.map { $0.toDomain() },
            senderDeleted: senderDeleted
        )
    }
}

struct ChatAttachmentDTO: Decodable {
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

    func toDomain() -> ChatAttachment {
        ChatAttachment(
            attachmentUuid: attachmentUuid,
            fileName: fileName,
            fileUrl: fileUrl,
            thumbnailUrl: thumbnailUrl,
            mp4Url: mp4Url,
            fileSize: fileSize,
            mimeType: mimeType,
            type: type,
            width: width,
            height: height,
            duration: duration,
            gifKey: gifKey
        )
    }
}

struct MessageReactionDTO: Decodable {
    let emoji: String
    let count: Int
    let mine: Bool
    let users: [ReactionUserDTO]?

    func toDomain() -> MessageReaction {
        MessageReaction(
            emoji: emoji,
            count: count,
            mine: mine,
            users: users?.map { $0.toDomain() }
        )
    }
}

struct ReactionUserDTO: Decodable {
    let userUuid: String?
    let at: String?

    func toDomain() -> ReactionUser {
        ReactionUser(userUuid: userUuid, at: at)
    }
}

struct ChatReceiptDTO: Decodable {
    let userUuid: String?
    let username: String?
    let fullName: String?
    let avatarUrl: String?
    let joinedAt: String?
    let lastDeliveredMessageId: Int64?
    let lastDeliveredAt: String?
    let lastReadMessageId: Int64?
    let lastReadAt: String?

    func toDomain() -> ChatReceipt {
        ChatReceipt(
            userUuid: userUuid,
            username: username,
            fullName: fullName,
            avatarUrl: avatarUrl,
            joinedAt: joinedAt,
            lastDeliveredMessageId: lastDeliveredMessageId,
            lastDeliveredAt: lastDeliveredAt,
            lastReadMessageId: lastReadMessageId,
            lastReadAt: lastReadAt
        )
    }
}

struct MessageStatusDTO: Decodable {
    let userId: Int64?
    let userUuid: String?
    let status: String?
    let deliveredAt: String?
    let readAt: String?

    func toDomain() -> MessageStatus {
        MessageStatus(
            userId: userId,
            userUuid: userUuid,
            status: status,
            deliveredAt: deliveredAt,
            readAt: readAt
        )
    }
}

struct ChatParticipantDTO: Decodable {
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

    func toDomain() -> ChatParticipant {
        ChatParticipant(
            userUuid: userUuid,
            userId: userId,
            username: username,
            firstName: firstName,
            lastName: lastName,
            fullName: fullName,
            nickname: nickname,
            avatarUrl: avatarUrl,
            role: role,
            online: online,
            lastSeenAt: lastSeenAt,
            joinedAt: joinedAt
        )
    }
}

struct ContactDTO: Decodable {
    let contactUuid: String
    let contactUserId: Int64?
    let contactUserUuid: String?
    let username: String?
    let firstName: String?
    let lastName: String?
    let fullName: String?
    let avatarUrl: String?
    let contactName: String?
    let online: Bool
    let lastSeenAt: String?
    let addedAt: String?

    func toDomain() -> Contact {
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
            lastSeenAt: lastSeenAt,
            addedAt: addedAt
        )
    }
}

struct PresenceDTO: Decodable {
    let userUuid: String
    let online: Bool
    let lastSeenAt: String?

    func toDomain() -> Presence {
        Presence(userUuid: userUuid, online: online, lastSeenAt: lastSeenAt)
    }
}
