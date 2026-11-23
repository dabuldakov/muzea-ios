import CoreGraphics
import Foundation

/// Единое состояние экрана переписки.
struct ChatConversationUiState: Equatable {
    var messages: [ChatMessage] = []
    var isLoading = false
    /// Догрузка истории вверх: true, пока сервер может отдать ещё страницу.
    var hasMoreHistory = true
    var isLoadingMore = false
    var error: String?
    var notice: String?

    /// Сообщение, на которое сейчас отвечаем.
    var replyTo: ChatMessage?
    /// Сообщение, которое сейчас редактируем.
    var editing: ChatMessage?

    var pinned: [ChatMessage] = []
    var receipts: [ChatReceipt] = []
    var receiptsLoaded = false
    /// Точные статусы по сообщению, загруженные при открытии «Деталей».
    var messageStatuses: [String: [MessageStatus]] = [:]
    /// Статусы собственных сообщений: uuid -> галочка.
    var statuses: [String: MessageDeliveryStatus] = [:]
    var failedMessages: Set<String> = []

    var selection: Set<String> = []
    var participants: [ChatParticipant] = []
    var forwardChats: [Chat] = []
    /// Выбранные вложения, ожидающие загрузки или уже загруженные.
    var pendingAttachments: [PendingChatAttachment] = []
    var isUploadingAttachments = false

    var isSelecting: Bool { !selection.isEmpty }
}

/// Источник вложения, выбранный в меню «прикрепить».
enum AttachmentSource {
    case photo
    case video
    case file
}

/// Плавающая карточка действий по сообщению.
struct MessagePopupState: Identifiable {
    let message: ChatMessage
    let point: CGPoint
    var id: String { message.messageUuid }
}

/// Модальные листы экрана переписки.
enum ActiveSheet: Identifiable {
    case forward
    case details(ChatMessage)
    case reaction(ChatMessage)
    case report(ChatMessage)
    case emojiGif

    var id: String {
        switch self {
        case .forward: return "forward"
        case .details(let message): return "details-\(message.messageUuid)"
        case .reaction(let message): return "reaction-\(message.messageUuid)"
        case .report(let message): return "report-\(message.messageUuid)"
        case .emojiGif: return "emoji-gif"
        }
    }
}

/// Системные алерты экрана переписки.
enum ActiveAlert: Identifiable {
    case error(String)
    case notice(String)
    case delete(ChatMessage)
    case deleteSelected
    case block(ChatMessage)

    var id: String {
        switch self {
        case .error(let message): return "error-\(message)"
        case .notice(let message): return "notice-\(message)"
        case .delete(let message): return "delete-\(message.messageUuid)"
        case .deleteSelected: return "delete-selected"
        case .block(let message): return "block-\(message.messageUuid)"
        }
    }
}
