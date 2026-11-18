import Foundation

/// Метаданные выбранного, но ещё не отправленного вложения. Файлы лежат рядом
/// с JSON и переживают перезапуск приложения.
struct StoredPendingAttachment: Codable, Identifiable, Equatable {
    let id: String
    let chatUuid: String
    let fileName: String
    let mimeType: String
    let kind: String
    let width: Int?
    let height: Int?
    let duration: Int?
    let filePath: String
    let thumbnailPath: String?
    var uploaded: ChatAttachment?
}

protocol PendingAttachmentStore {
    func load(chatUuid: String) -> [StoredPendingAttachment]
    func save(record: StoredPendingAttachment, data: Data, thumbnail: Data?) throws
    func update(_ record: StoredPendingAttachment)
    func remove(id: String)
    func clear(chatUuid: String)
    func clearAll()
}

/// Дисковая очередь вложений: `Application Support/pending-attachments`.
final class FilePendingAttachmentStore: PendingAttachmentStore {
    private let root: URL
    private let manifestURL: URL
    private let lock = NSLock()

    init(root: URL? = nil) {
        if let root {
            self.root = root
        } else {
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.root = base.appendingPathComponent("pending-attachments", isDirectory: true)
        }
        manifestURL = self.root.appendingPathComponent("manifest.json")
    }

    func load(chatUuid: String) -> [StoredPendingAttachment] {
        lock.lock()
        defer { lock.unlock() }
        return readAll().filter {
            $0.chatUuid == chatUuid && FileManager.default.fileExists(atPath: $0.filePath)
        }
    }

    func save(record: StoredPendingAttachment, data: Data, thumbnail: Data?) throws {
        lock.lock()
        defer { lock.unlock() }

        let directory = root.appendingPathComponent(record.id, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        FileProtection.apply(toDirectory: directory)
        let fileURL = directory.appendingPathComponent(
            AttachmentFiles.sanitize(record.fileName)
        )
        try data.write(to: fileURL, options: .atomic)
        FileProtection.apply(to: fileURL)

        var thumbnailPath: String?
        if let thumbnail {
            let thumbURL = directory.appendingPathComponent("thumb.jpg")
            try thumbnail.write(to: thumbURL, options: .atomic)
            FileProtection.apply(to: thumbURL)
            thumbnailPath = thumbURL.path
        }

        var updated = record
        updated = StoredPendingAttachment(
            id: record.id,
            chatUuid: record.chatUuid,
            fileName: record.fileName,
            mimeType: record.mimeType,
            kind: record.kind,
            width: record.width,
            height: record.height,
            duration: record.duration,
            filePath: fileURL.path,
            thumbnailPath: thumbnailPath,
            uploaded: record.uploaded
        )
        var all = readAll()
        all.removeAll { $0.id == updated.id }
        all.append(updated)
        writeAll(all)
    }

    func update(_ record: StoredPendingAttachment) {
        lock.lock()
        defer { lock.unlock() }
        var all = readAll()
        all.removeAll { $0.id == record.id }
        all.append(record)
        writeAll(all)
    }

    func remove(id: String) {
        lock.lock()
        defer { lock.unlock() }
        var all = readAll()
        all.removeAll { $0.id == id }
        writeAll(all)
        try? FileManager.default.removeItem(at: root.appendingPathComponent(id, isDirectory: true))
    }

    func clear(chatUuid: String) {
        lock.lock()
        defer { lock.unlock() }
        var all = readAll()
        let removed = all.filter { $0.chatUuid == chatUuid }
        all.removeAll { $0.chatUuid == chatUuid }
        writeAll(all)
        for item in removed {
            try? FileManager.default.removeItem(
                at: root.appendingPathComponent(item.id, isDirectory: true)
            )
        }
    }

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: root)
    }

    private func readAll() -> [StoredPendingAttachment] {
        guard let data = try? Data(contentsOf: manifestURL),
              let decoded = try? JSONDecoder().decode([StoredPendingAttachment].self, from: data) else {
            return []
        }
        return decoded
    }

    private func writeAll(_ items: [StoredPendingAttachment]) {
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            FileProtection.apply(toDirectory: root)
            let data = try JSONEncoder().encode(items)
            try data.write(to: manifestURL, options: .atomic)
            FileProtection.apply(to: manifestURL)
        } catch {
            // Очередь не должна ронять отправку.
        }
    }
}
