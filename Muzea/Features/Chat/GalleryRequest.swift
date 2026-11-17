import Foundation

/// Запрос на открытие полноэкранной галереи из пузыря. Хранит исходное
/// сообщение, чтобы действия «ответить» и «переслать» не зависели от того,
/// какой именно кадр сейчас показан.
struct GalleryRequest: Identifiable {
    let id = UUID()
    let message: ChatMessage
    let images: [ChatAttachment]
    let startIndex: Int

    /// nil, если в сообщении нет изображений — открывать нечего.
    init?(message: ChatMessage, tappedIndex: Int) {
        let images = AttachmentPolicy.images(in: message.attachments ?? [])
        guard !images.isEmpty else { return nil }
        self.message = message
        self.images = images
        self.startIndex = min(max(tappedIndex, 0), images.count - 1)
    }

    var senderName: String? {
        message.senderDeleted == true ? L10n.deletedUser : message.senderName
    }
}

/// Действие из галереи, которое нужно выполнить уже после её закрытия:
/// иначе SwiftUI попытается показать второй лист поверх первого.
enum GalleryAction {
    case reply(ChatMessage)
    case forward(ChatMessage)
}
