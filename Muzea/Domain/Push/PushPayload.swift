import Foundation

struct ChatPushTarget: Equatable {
    let chatUuid: String
    let title: String?
    let avatarUrl: String?
    let messageUuid: String?
}

enum PushRoute: Equatable {
    case chat(ChatPushTarget)
    case news(id: Int64)
}

/// Разбор data-only FCM. Android и iOS используют одни и те же ключи
/// (`type`, `chatUuid`, `chatTitle`, `senderName`, `messageText`, `newsId`).
enum PushPayload {
    static func route(from data: [AnyHashable: Any]) -> PushRoute? {
        let type = firstString(data, ["type"])?.uppercased()
        switch type {
        case "MESSAGE":
            guard let chatUuid = firstString(data, ["chatUuid", "chat_uuid"]),
                  !chatUuid.isEmpty else { return nil }
            let sender = firstString(data, ["senderName", "sender_name", "sender", "username"])
            let chatTitle = firstString(data, ["chatTitle", "chat_title", "chatName"])
            let avatar = firstString(data, ["chatAvatar", "senderAvatar"])
            return .chat(ChatPushTarget(
                chatUuid: chatUuid,
                title: chatTitle ?? sender,
                avatarUrl: avatar,
                messageUuid: firstString(data, ["messageUuid", "message_uuid"])
            ))
        case "NEWS":
            guard let raw = firstString(data, ["newsId", "news_id"]),
                  let id = Int64(raw) else { return nil }
            return .news(id: id)
        default:
            return nil
        }
    }

    static func title(for data: [AnyHashable: Any]) -> String? {
        firstString(data, ["title"])
    }

    static func body(for data: [AnyHashable: Any]) -> String? {
        firstString(data, ["body", "messageText", "text", "message"])
    }
}

enum PushRouteNotification {
    static let name = Notification.Name("muzea.push.route")
}

private func firstString(_ data: [AnyHashable: Any], _ keys: [String]) -> String? {
    for key in keys {
        if let value = data[key] as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        if let value = data[AnyHashable(key)] as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
    }
    return nil
}
