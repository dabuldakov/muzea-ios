import Foundation
import UIKit
import ImageIO
import CryptoKit

/// Memory- и дисковый кэш картинок (аналог Glide на Android).
///
/// `AsyncImage` не умеет ни авторизацию, ни downsample, а сервер аватаров
/// отдаёт `Cache-Control: no-store`, поэтому без своего кэша каждая ячейка
/// списка заново качает полноразмерный PNG. Здесь картинка один раз
/// скачивается, уменьшается до нужного размера и кладётся в Caches.
final class RemoteImageCache {
    static let shared = RemoteImageCache()

    /// Токен для защищённых картинок. Публичные аватары работают и без него,
    /// но с заголовком надёжнее, если сервер закроет endpoint.
    var authTokenProvider: (() -> String?)?

    private let memory = NSCache<NSString, UIImage>()
    private let session: URLSession
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let lock = NSLock()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    private var didTrimDisk = false
    private let maxDiskFiles = 400

    init(session: URLSession = .shared) {
        self.session = session
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        cacheDirectory = base.appendingPathComponent("RemoteImages", isDirectory: true)
        memory.countLimit = 300
        memory.totalCostLimit = 64 * 1024 * 1024
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func image(for url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        let pixelSize = max(1, Int(maxPixelSize.rounded(.up)))
        let memoryKey = "\(url.absoluteString)|\(pixelSize)" as NSString
        if let cached = memory.object(forKey: memoryKey) {
            return cached
        }

        let key = memoryKey as String
        let task: Task<UIImage?, Never>
        lock.lock()
        if let existing = inFlight[key] {
            task = existing
        } else {
            task = Task.detached(priority: .utility) { [weak self] in
                await self?.load(url: url, pixelSize: pixelSize)
            }
            inFlight[key] = task
        }
        lock.unlock()

        let image = await task.value
        lock.lock()
        inFlight[key] = nil
        lock.unlock()

        if let image {
            memory.setObject(image, forKey: memoryKey, cost: image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0)
        }
        return image
    }

    // MARK: - Loading

    private func load(url: URL, pixelSize: Int) async -> UIImage? {
        trimDiskIfNeeded()

        let data: Data
        if let cached = try? Data(contentsOf: fileURL(for: url)), !cached.isEmpty {
            data = cached
        } else {
            guard let downloaded = await download(url) else { return nil }
            data = downloaded
            try? data.write(to: fileURL(for: url), options: .atomic)
        }

        return Self.downsample(data, maxPixelSize: pixelSize)
    }

    private func download(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "GET"
        if shouldAuthorize(url), let token = authTokenProvider?(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  !data.isEmpty else { return nil }
            return data
        } catch {
            return nil
        }
    }

    private func shouldAuthorize(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return [Config.chatBaseURL, Config.makeupBaseURL, Config.authBaseURL]
            .compactMap { $0.host?.lowercased() }
            .contains(host)
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent(name + ".img")
    }

    private func trimDiskIfNeeded() {
        lock.lock()
        if didTrimDisk {
            lock.unlock()
            return
        }
        didTrimDisk = true
        lock.unlock()

        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: keys
        ), files.count > maxDiskFiles else { return }

        let sorted = files.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
            return l < r
        }
        for file in sorted.prefix(files.count - maxDiskFiles) {
            try? fileManager.removeItem(at: file)
        }
    }

    static func downsample(_ data: Data, maxPixelSize: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: image)
    }

    func clear() {
        memory.removeAllObjects()
        lock.lock()
        inFlight.removeAll()
        didTrimDisk = false
        lock.unlock()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}
