import Foundation

/// Скачивает вложения во временные файлы и переиспользует их между плеером,
/// share sheet и повторными открытиями. Потокобезопасен для параллельных строк.
final class AttachmentFileCache {
    static let shared = AttachmentFileCache()

    private let directory: URL
    private let lock = NSLock()
    private var files: [String: URL] = [:]

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("attachment-cache", isDirectory: true)
    }

    func localURL(
        attachmentUuid: String,
        fileName: String,
        repository: AttachmentRepository
    ) async -> URL? {
        if let cached = cachedURL(attachmentUuid: attachmentUuid) {
            return cached
        }
        guard let data = try? await repository.download(attachmentUuid: attachmentUuid),
              let url = AttachmentFiles.write(
                data: data,
                fileName: fileName,
                directory: directory.appendingPathComponent(attachmentUuid, isDirectory: true)
              ) else {
            return nil
        }
        lock.lock()
        files[attachmentUuid] = url
        lock.unlock()
        return url
    }

    func cachedURL(attachmentUuid: String) -> URL? {
        lock.lock()
        let url = files[attachmentUuid]
        lock.unlock()
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func removeAll() {
        lock.lock()
        files.removeAll()
        lock.unlock()
        try? FileManager.default.removeItem(at: directory)
    }
}
