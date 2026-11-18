import Foundation

protocol ErrorStoring: AnyObject {
    var overflowed: Bool { get set }
    var lastUploadedAt: String? { get set }

    func append(_ event: ErrorEvent)
    func pending(limit: Int) -> [ErrorEvent]
    func remove(eventIds: Set<String>)
    func sizeBytes() -> Int64
    func clear()
}

/// Дисковый буфер диагностики: JSON-lines в Application Support.
/// Не в Caches, чтобы «Очистить кэш» не стирал ошибки.
final class FileErrorStore: ErrorStoring {
    static let defaultMaxBytes: Int64 = 5 * 1024 * 1024

    private let fileURL: URL
    private let defaults: UserDefaults
    private let maxBytes: Int64
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let overflowKey = "error_reporting.buffer_overflowed"
    private let uploadKey = "error_reporting.last_uploaded_at"

    init(
        fileURL: URL? = nil,
        defaults: UserDefaults = .standard,
        maxBytes: Int64 = FileErrorStore.defaultMaxBytes
    ) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.fileURL = base
                .appendingPathComponent("telemetry", isDirectory: true)
                .appendingPathComponent("error_events.jsonl")
        }
        self.defaults = defaults
        self.maxBytes = maxBytes
    }

    var overflowed: Bool {
        get { defaults.bool(forKey: overflowKey) }
        set { defaults.set(newValue, forKey: overflowKey) }
    }

    var lastUploadedAt: String? {
        get { defaults.string(forKey: uploadKey) }
        set { defaults.set(newValue, forKey: uploadKey) }
    }

    func append(_ event: ErrorEvent) {
        lock.lock()
        defer { lock.unlock() }
        guard sizeBytesLocked() < maxBytes else {
            // Старое не удаляем: переполнение — сигнал, что отправка не проходит.
            overflowed = true
            return
        }
        guard let data = try? encoder.encode(event) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileProtection.apply(toDirectory: fileURL.deletingLastPathComponent())
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data + Data([0x0A]))
        } else {
            try? (data + Data([0x0A])).write(to: fileURL, options: .atomic)
        }
        FileProtection.apply(to: fileURL)
    }

    func pending(limit: Int) -> [ErrorEvent] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8) else { return [] }
        return text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .prefix(limit)
            .compactMap { line in
                try? decoder.decode(ErrorEvent.self, from: Data(line.utf8))
            }
    }

    func remove(eventIds: Set<String>) {
        lock.lock()
        defer { lock.unlock() }
        guard !eventIds.isEmpty,
              let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8) else { return }
        let keep = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .filter { line in
                guard let event = try? decoder.decode(ErrorEvent.self, from: Data(line.utf8)) else {
                    return true
                }
                return !eventIds.contains(event.eventId)
            }
        let result = keep.isEmpty ? "" : keep.joined(separator: "\n") + "\n"
        try? result.write(to: fileURL, atomically: true, encoding: .utf8)
        FileProtection.apply(to: fileURL)
    }

    func sizeBytes() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        return sizeBytesLocked()
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: fileURL)
        overflowed = false
    }

    private func sizeBytesLocked() -> Int64 {
        let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }
}
