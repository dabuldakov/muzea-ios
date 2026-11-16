import Foundation

/// Подписи для цитат, ответов, пересылки и панели закреплённых.
enum MessagePreviewText {

    static func senderName(_ message: MessageResponse?, myUserUuid: String?) -> String {
        guard let message else { return "Неизвестный отправитель" }
        if let uuid = message.senderUuid, uuid == myUserUuid { return "Вы" }
        if message.senderDeleted == true { return "Удалённый пользователь" }
        if let name = message.senderName, !name.isEmpty { return name }
        return "Неизвестный отправитель"
    }

    /// Короткий текст цитаты: текст, тип вложения или заглушка.
    static func preview(_ message: MessageResponse?) -> String {
        guard let message else { return "Сообщение" }
        if message.isDeleted == true { return "Сообщение удалено" }
        if let text = message.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }
        switch (message.messageType ?? "").uppercased() {
        case "GIF": return "GIF"
        case "IMAGE": return "Изображение"
        case "VIDEO", "VIDEO_NOTE": return "Видео"
        case "VOICE", "AUDIO": return "Аудио"
        case "FILE": return "Файл"
        default: return "Вложение"
        }
    }
}
