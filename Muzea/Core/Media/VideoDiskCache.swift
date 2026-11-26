import Foundation
import CryptoKit

/// Дисковый кэш видеофрагментов.
///
/// AVPlayer не умеет отдавать уже скачанные куски так же прозрачно, как
/// ExoPlayer на Android, поэтому кэшируем ролик целиком после первого
/// проигрывания (на Wi-Fi и в пределах лимита) и затем открываем локальный
/// файл. Это даёт офлайн-повтор и не расходует мобильный трафик дважды.
final class VideoDiskCache {
    static let shared = VideoDiskCache()

    private static let maxBytes: Int64 = 300 * 1024 * 1024
    private let fileManager = FileManager.default
    let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.directory = base.appendingPathComponent("video_cache", isDirectory: true)
        }
        try? fileManager.createDirectory(
            at: self.directory,
            withIntermediateDirectories: true
        )
    }

    /// Локальная копия ролика, если она уже скачана полностью.
    func cachedFile(for remoteURL: URL) -> URL? {
        let file = directory.appendingPathComponent(cacheKey(for: remoteURL))
        guard fileManager.fileExists(atPath: file.path) else { return nil }
        let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return size > 0 ? file : nil
    }

    func sizeBytes() -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }

    func clear() {
        guard let items = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }
        for item in items {
            try? fileManager.removeItem(at: item)
        }
    }

    func remove(for remoteURL: URL) {
        let file = directory.appendingPathComponent(cacheKey(for: remoteURL))
        try? fileManager.removeItem(at: file)
    }

    /// Сохраняет готовые байты (используется тестами и будущими докачками).
    func store(data: Data, for remoteURL: URL) throws {
        let target = directory.appendingPathComponent(cacheKey(for: remoteURL))
        try data.write(to: target, options: .atomic)
        trimIfNeeded()
    }

    /// Скачивает ролик целиком и атомарно кладёт в кэш.
    ///
    /// Вызывается только для Wi-Fi/нелимитированного трафика и роликов
    /// разумного размера: иначе кэш сам станет источником перерасхода.
    func prefetch(url: URL, token: String?, expectedSize: Int64?) async {
        guard expectedSize.map({ $0 <= Self.maxBytes }) ?? true else { return }
        if cachedFile(for: url) != nil { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (temporaryURL, response) = try await URLSession.shared.download(for: request)
            defer { try? fileManager.removeItem(at: temporaryURL) }
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else { return }
            let target = directory.appendingPathComponent(cacheKey(for: url))
            try? fileManager.removeItem(at: target)
            try fileManager.moveItem(at: temporaryURL, to: target)
            trimIfNeeded()
        } catch {
            // Кэш — необязательная оптимизация: ошибку сети не показываем.
        }
    }

    private func trimIfNeeded() {
        guard sizeBytes() > Self.maxBytes else { return }
        let files = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        )) ?? []
        let sorted = files.sorted {
            let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            return left < right
        }
        for file in sorted {
            guard sizeBytes() > Self.maxBytes else { break }
            try? fileManager.removeItem(at: file)
        }
    }

    private func cacheKey(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
