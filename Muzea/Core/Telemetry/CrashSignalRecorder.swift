import Darwin
import Foundation

/// Минимальный перехват фатальных сигналов: в обработчике нельзя пользоваться
/// Foundation, поэтому пишем 4 байта номера сигнала в заранее открытый файл.
/// На следующем запуске `drain()` превращает их в события `CRASH`.
final class CrashSignalRecorder {
    private let pendingURL: URL
    private var installed = false

    /// Глобальные для C-обработчика: замыкание не должно ничего захватывать.
    fileprivate static var descriptor: Int32 = -1

    init(pendingURL: URL? = nil) {
        if let pendingURL {
            self.pendingURL = pendingURL
        } else {
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.pendingURL = base
                .appendingPathComponent("telemetry", isDirectory: true)
                .appendingPathComponent("crash_signals.bin")
        }
    }

    func install() {
        guard !installed else { return }
        installed = true
        try? FileManager.default.createDirectory(
            at: pendingURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        Self.descriptor = pendingURL.path.withCString {
            open($0, O_WRONLY | O_CREAT | O_APPEND, 0o644)
        }
        guard Self.descriptor >= 0 else { return }
        FileProtection.apply(to: pendingURL)

        for number in Self.signals {
            signal(number, crashHandler)
        }
    }

    /// Забирает сохранённые сигналы и удаляет файл.
    func drain() -> [String] {
        guard let data = try? Data(contentsOf: pendingURL) else { return [] }
        try? FileManager.default.removeItem(at: pendingURL)

        var messages: [String] = []
        var index = data.startIndex
        while index < data.endIndex {
            let end = data.index(index, offsetBy: 4, limitedBy: data.endIndex) ?? data.endIndex
            let chunk = data[index..<end]
            index = end
            guard chunk.count == 4 else { continue }
            let number = chunk.withUnsafeBytes { raw -> Int32 in
                var value: Int32 = 0
                withUnsafeMutableBytes(of: &value) { destination in
                    destination.copyBytes(from: raw)
                }
                return value
            }
            messages.append("Fatal signal \(number)")
        }
        return messages
    }

    private static let signals: [Int32] = [
        SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGTRAP
    ]
}

/// C-совместимый обработчик: только async-signal-safe вызовы.
private func crashHandler(_ number: Int32) {
    var value = number
    withUnsafeBytes(of: &value) { raw in
        guard CrashSignalRecorder.descriptor >= 0 else { return }
        _ = write(CrashSignalRecorder.descriptor, raw.baseAddress, raw.count)
    }
    signal(number, SIG_DFL)
    raise(number)
}
