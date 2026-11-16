import Foundation

/// Действия над сообщением, которые показывает контекстное меню.
enum MessageAction: Hashable {
    case react
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
        message: MessageResponse,
        myUserUuid: String?,
        isGroupChat: Bool
    ) -> Result {
        guard message.isDeleted != true else {
            return Result(actions: [], showStatus: false)
        }

        let isMine = message.senderUuid != nil && message.senderUuid == myUserUuid
        // После серверного эха uuid остаётся локальным, поэтому признак
        // серверного сообщения — messageId.
        let isServerMessage = message.messageId != nil
        var actions: [MessageAction] = [.react]

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
