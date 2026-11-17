import Foundation

/// Исходящее сообщение, сохранённое до подтверждения сервера. Повторяется с
/// тем же `clientMessageId`, поэтому потерянный ответ не создаёт дубль.
struct PendingChatMessage: Codable, Identifiable, Equatable {
    var id: String { clientMessageId }
    let clientMessageId: String
    let localUuid: String
    let chatUuid: String
    let text: String
    let replyToMessageUuid: String?
    let power: Int
    let createdAt: String
    /// Медиа-сообщение: тип и уже загруженные вложения.
    var messageType: String? = nil
    var attachments: [ChatAttachment]? = nil
}

/// Дисковая очередь исходящих по чатам. Аналог `outbox_v2.json` на Android.
protocol ChatOutboxStore {
    func pending(chatUuid: String) -> [PendingChatMessage]
    func save(_ message: PendingChatMessage)
    func remove(clientMessageId: String)
    func clearAll()
}

final class FileChatOutboxStore: ChatOutboxStore {
    private let fileURL: URL
    private let lock = NSLock()

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let directory = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.fileURL = directory.appendingPathComponent("chat-outbox.json")
        }
    }

    func pending(chatUuid: String) -> [PendingChatMessage] {
        loadAll().filter { $0.chatUuid == chatUuid }
    }

    func save(_ message: PendingChatMessage) {
        lock.lock()
        defer { lock.unlock() }
        var all = loadAll()
        all.removeAll { $0.clientMessageId == message.clientMessageId }
        all.append(message)
        write(all)
    }

    func remove(clientMessageId: String) {
        lock.lock()
        defer { lock.unlock() }
        var all = loadAll()
        all.removeAll { $0.clientMessageId == clientMessageId }
        write(all)
    }

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func loadAll() -> [PendingChatMessage] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([PendingChatMessage].self, from: data)) ?? []
    }

    private func write(_ messages: [PendingChatMessage]) {
        guard !messages.isEmpty else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(messages)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Очередь не должна ронять отправку: худший случай — сообщение
            // останется только в памяти до перезапуска.
        }
    }
}
