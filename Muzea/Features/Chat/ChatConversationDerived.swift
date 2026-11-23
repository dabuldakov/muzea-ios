import Foundation

/// Производные значения состояния переписки, не требующие доступа к приватным
/// членам ViewModel.
extension ChatConversationUiState {

    /// Самое новое серверное время создания сообщения (локальные не считаем).
    var newestTimestamp: String? {
        messages
            .compactMap { message -> String? in
                guard message.messageUuid.hasPrefix("local-") == false,
                      let createdAt = message.createdAt,
                      !createdAt.isEmpty else { return nil }
                return createdAt
            }
            .max()
    }
}

/// Оптимистичный пузырь для сообщения из durable-очереди.
extension PendingChatMessage {

    func optimistic(myUserUuid: String?) -> ChatMessage {
        ChatMessage(
            messageUuid: localUuid,
            messageId: nil,
            chatUuid: chatUuid,
            senderId: nil,
            senderUuid: myUserUuid,
            senderName: nil,
            senderAvatar: nil,
            text: text,
            messageType: messageType ?? "TEXT",
            replyToMessageUuid: replyToMessageUuid,
            forwardedFromMessageUuid: nil,
            forwardedFromUserUuid: nil,
            isEdited: false,
            isDeleted: false,
            isPinned: false,
            createdAt: createdAt,
            updatedAt: nil,
            reactions: [],
            power: power,
            attachments: attachments
        )
    }
}
