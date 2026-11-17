import Foundation

/// Тип вложения в терминах API.
enum AttachmentKind: String, Hashable {
    case image = "IMAGE"
    case video = "VIDEO"
    case audio = "AUDIO"
    case document = "DOCUMENT"
    case gif = "GIF"
}

/// Белый список и лимиты — те же, что проверяет сервер (`AttachmentPolicy`).
enum AttachmentPolicy {
    static let maxAttachmentsPerMessage = 10
    static let maxImageBytes: Int64 = 50 * 1024 * 1024
    static let maxVideoBytes: Int64 = 200 * 1024 * 1024
    static let maxAudioBytes: Int64 = 50 * 1024 * 1024
    static let maxDocumentBytes: Int64 = 100 * 1024 * 1024
    static let maxThumbnailBytes: Int64 = 5 * 1024 * 1024

    struct Rule {
        let kind: AttachmentKind
        let mimeType: String
        let maxBytes: Int64
    }

    private static let rules: [String: Rule] = [
        "jpg": Rule(kind: .image, mimeType: "image/jpeg", maxBytes: maxImageBytes),
        "jpeg": Rule(kind: .image, mimeType: "image/jpeg", maxBytes: maxImageBytes),
        "png": Rule(kind: .image, mimeType: "image/png", maxBytes: maxImageBytes),
        "webp": Rule(kind: .image, mimeType: "image/webp", maxBytes: maxImageBytes),
        "mp4": Rule(kind: .video, mimeType: "video/mp4", maxBytes: maxVideoBytes),
        "mov": Rule(kind: .video, mimeType: "video/quicktime", maxBytes: maxVideoBytes),
        "mp3": Rule(kind: .audio, mimeType: "audio/mpeg", maxBytes: maxAudioBytes),
        "m4a": Rule(kind: .audio, mimeType: "audio/mp4", maxBytes: maxAudioBytes),
        "aac": Rule(kind: .audio, mimeType: "audio/aac", maxBytes: maxAudioBytes),
        "ogg": Rule(kind: .audio, mimeType: "audio/ogg", maxBytes: maxAudioBytes),
        "opus": Rule(kind: .audio, mimeType: "audio/ogg", maxBytes: maxAudioBytes),
        "wav": Rule(kind: .audio, mimeType: "audio/wav", maxBytes: maxAudioBytes),
        "pdf": Rule(kind: .document, mimeType: "application/pdf", maxBytes: maxDocumentBytes),
        "txt": Rule(kind: .document, mimeType: "text/plain", maxBytes: maxDocumentBytes),
        "csv": Rule(kind: .document, mimeType: "text/csv", maxBytes: maxDocumentBytes),
        "doc": Rule(kind: .document, mimeType: "application/msword", maxBytes: maxDocumentBytes),
        "docx": Rule(
            kind: .document,
            mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            maxBytes: maxDocumentBytes
        ),
        "xls": Rule(kind: .document, mimeType: "application/vnd.ms-excel", maxBytes: maxDocumentBytes),
        "xlsx": Rule(
            kind: .document,
            mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            maxBytes: maxDocumentBytes
        ),
        "ppt": Rule(kind: .document, mimeType: "application/vnd.ms-powerpoint", maxBytes: maxDocumentBytes),
        "pptx": Rule(
            kind: .document,
            mimeType: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            maxBytes: maxDocumentBytes
        )
    ]

    static func rule(for fileName: String) -> Rule? {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return rules[ext]
    }

    /// Ошибка валидации или nil, если файл можно отправлять.
    static func validationError(fileName: String, size: Int64) -> String? {
        guard let rule = rule(for: fileName) else {
            return "Этот тип файла не поддерживается"
        }
        guard size > 0 else { return "Файл пустой" }
        guard size <= rule.maxBytes else {
            return "Файл больше \(rule.maxBytes / (1024 * 1024)) МБ"
        }
        return nil
    }

    /// Тип сообщения по набору вложений — как `messageTypeFor` на Android.
    static func messageType(for kinds: [AttachmentKind]) -> String {
        guard !kinds.isEmpty else { return "TEXT" }
        if kinds.allSatisfy({ $0 == .image }) { return AttachmentKind.image.rawValue }
        if kinds.allSatisfy({ $0 == .audio }) { return AttachmentKind.audio.rawValue }
        if kinds.count == 1, kinds[0] == .video { return AttachmentKind.video.rawValue }
        if kinds.count == 1, kinds[0] == .gif { return AttachmentKind.gif.rawValue }
        return "FILE"
    }

    static func kind(fromServerType type: String?) -> AttachmentKind? {
        guard let type else { return nil }
        let normalized = type.uppercased()
        if normalized == "FILE" { return .document }
        return AttachmentKind(rawValue: normalized)
    }

    /// Тип вложения для UI: серверный `type`, иначе расширение файла.
    static func kind(of attachment: ChatAttachment) -> AttachmentKind {
        kind(fromServerType: attachment.type)
            ?? rule(for: attachment.fileName ?? "")?.kind
            ?? .document
    }

    /// Только изображения — сетка в пузыре и полноэкранная галерея.
    static func images(in attachments: [ChatAttachment]) -> [ChatAttachment] {
        attachments.filter { kind(of: $0) == .image }
    }
}

/// Вложение, выбранное в композере: локальное имя, прогресс и результат.
struct PendingChatAttachment: Identifiable, Equatable {
    let id: String
    let fileName: String
    let kind: AttachmentKind
    var uploaded: ChatAttachment?
    /// 0...1; 0 — размер ещё неизвестен, показываем индикатор без значения.
    var progress: Double = 0
    /// Ошибка загрузки именно этого файла: пузырь можно повторить отдельно.
    var error: String?

    var isUploaded: Bool { uploaded != nil }
    var isUploading: Bool { uploaded == nil && error == nil }

    /// Прогресс для `ProgressView`: 0 — неопределённый.
    var normalizedProgress: Double {
        min(1, max(0, progress))
    }
}

/// Абсолютные URL вложений. Сервер отдаёт `fileUrl` ключом MinIO, поэтому
/// скачивание всегда идёт через прокси `/api/attachments/{uuid}`.
enum AttachmentURLResolver {
    static func fileURL(for attachment: ChatAttachment) -> URL? {
        if let uuid = attachment.attachmentUuid, !uuid.isEmpty {
            return Config.chatBaseURL.appendingPathComponent("api/attachments/\(uuid)")
        }
        return absolute(attachment.fileUrl, base: Config.chatBaseURL)
    }

    static func previewURL(for attachment: ChatAttachment) -> URL? {
        if let uuid = attachment.attachmentUuid, !uuid.isEmpty,
           attachment.thumbnailUrl != nil {
            return Config.chatBaseURL.appendingPathComponent("api/attachments/\(uuid)/preview")
        }
        return absolute(attachment.thumbnailUrl, base: Config.chatBaseURL)
            ?? fileURL(for: attachment)
    }

    static func absolute(_ path: String?, base: URL) -> URL? {
        guard let path, !path.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        let cleaned = trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : trimmed
        return URL(string: cleaned, relativeTo: base)?.absoluteURL
    }
}
