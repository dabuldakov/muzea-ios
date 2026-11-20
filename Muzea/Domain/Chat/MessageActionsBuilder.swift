import Foundation

/// Действия над сообщением, которые показывает контекстное меню.
enum MessageAction: Hashable {
    case react
    case retry
    case copy
    case reply
    case select
    case edit
    case delete
    case forward
    case pin
    case unpin
    case report
    case block
    case status
}

/// Собирает список действий над сообщением. Чистая логика, без UI.
enum MessageActionsBuilder {

    struct Result: Equatable {
        let actions: [MessageAction]
        let showStatus: Bool
    }

    static func build(
        message: ChatMessage,
        myUserUuid: String?,
        isGroupChat: Bool,
        failedMessages: Set<String> = []
    ) -> Result {
        guard message.isDeleted != true else {
            return Result(actions: [], showStatus: false)
        }

        let isMine = message.isSent(by: myUserUuid)
        // После серверного эха uuid остаётся локальным, поэтому признак
        // серверного сообщения — messageId.
        let isServerMessage = message.messageId != nil
        var actions: [MessageAction] = [.react]

        if message.messageUuid.hasPrefix("local-"), failedMessages.contains(message.messageUuid) {
            actions.append(.retry)
        }

        if let text = message.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            actions.append(.copy)
        }

        if isServerMessage {
            actions.append(.reply)
            actions.append(.select)
        }

        if isMine, isServerMessage, !(message.text ?? "").isEmpty {
            actions.append(.edit)
        }

        if isMine, isServerMessage {
            actions.append(.delete)
        }

        if isServerMessage {
            actions.append(.forward)
            actions.append(message.isPinned == true ? .unpin : .pin)
        }

        if !isMine, isServerMessage {
            actions.append(.report)
            if message.senderUuid != nil {
                actions.append(.block)
            }
        }

        // В личных чатах статус виден по галочкам; список участников — в группах.
        // Авторов реакций показываем в «Деталях» для любого сообщения.
        let showStatus = isMine && isServerMessage && isGroupChat
        let hasReactions = !(message.reactions ?? []).isEmpty
        if showStatus || hasReactions {
            actions.append(.status)
        }

        return Result(actions: actions, showStatus: showStatus)
    }
}

extension MessageAction {
    var title: String {
        switch self {
        case .react: return L10n.reaction
        case .retry: return L10n.retry
        case .copy: return L10n.copy
        case .reply: return L10n.reply
        case .select: return L10n.select
        case .edit: return L10n.edit
        case .delete: return L10n.delete
        case .forward: return L10n.forward
        case .pin: return L10n.pin
        case .unpin: return L10n.unpin
        case .report: return L10n.report
        case .block: return L10n.block
        case .status: return L10n.details
        }
    }

    var systemImage: String {
        switch self {
        case .react: return "face.smiling"
        case .retry: return "arrow.clockwise"
        case .copy: return "doc.on.doc"
        case .reply: return "arrowshape.turn.up.left"
        case .select: return "checkmark.circle"
        case .edit: return "pencil"
        case .delete: return "trash"
        case .forward: return "arrowshape.turn.up.right"
        case .pin: return "pin"
        case .unpin: return "pin.slash"
        case .report: return "exclamationmark.bubble"
        case .block: return "hand.raised"
        case .status: return "info.circle"
        }
    }

    var isDestructive: Bool {
        self == .delete || self == .block
    }
}
