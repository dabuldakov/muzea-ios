import Foundation

/// Подписи для цитат, ответов, пересылки и панели закреплённых.
enum MessagePreviewText {

    static func senderName(_ message: ChatMessage?, myUserUuid: String?) -> String {
        guard let message else { return L10n.unknownSender }
        if message.isSent(by: myUserUuid) { return L10n.you }
        if message.senderDeleted == true { return L10n.deletedUser }
        if let name = message.senderName, !name.isEmpty { return name }
        return L10n.unknownSender
    }

    /// Короткий текст цитаты: текст, тип вложения или заглушка.
    static func preview(_ message: ChatMessage?) -> String {
        guard let message else { return L10n.previewMessage }
        if message.isDeleted == true { return L10n.messageDeleted }
        if let text = message.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }
        switch (message.messageType ?? "").uppercased() {
        case "GIF": return "GIF"
        case "IMAGE": return L10n.previewImage
        case "VIDEO", "VIDEO_NOTE": return L10n.videoFallback
        case "VOICE", "AUDIO": return L10n.audioFallback
        case "FILE": return L10n.fileFallback
        default: return L10n.attachmentFallback
        }
    }
}
