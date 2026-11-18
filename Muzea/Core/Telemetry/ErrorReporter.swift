import Foundation
import UIKit

/// Метаданные сборки/устройства для отчёта — как `BuildConfig`/`Build` в Android.
struct ErrorMetadata: Equatable {
    let appVersion: String
    let versionCode: Int
    let buildType: String
    let device: String
    let os: String

    static func current() -> ErrorMetadata {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Int(info?["CFBundleVersion"] as? String ?? "") ?? 0
        let device = UIDevice.current
        return ErrorMetadata(
            appVersion: version,
            versionCode: build,
            buildType: {
                #if DEBUG
                return "debug"
                #else
                return "release"
                #endif
            }(),
            device: device.model,
            os: "\(device.systemName) \(device.systemVersion)"
        )
    }
}

/// Диагностика ошибок: кольцевой буфер на диске + отправка пачками при старте.
/// Краши (NSException и фатальные сигналы) сохраняются и уходят при следующем
/// запуске. Перехваченные ошибки пишутся через `logCaught`.
final class ErrorReporter {
    static let shared = ErrorReporter()

    private let store: ErrorStoring
    private let signals: CrashSignalRecorder
    private let metadata: ErrorMetadata

    private let lock = NSLock()
    private var uploader: ((ErrorReportRequest) async -> Bool)?
    private var userIdProvider: () -> String? = { nil }
    private var isDraining = false
    private var installed = false

    private static var previousExceptionHandler: NSUncaughtExceptionHandler?

    private static let batchSize = 100
    private static let maxBatches = 5
    private static let maxMessage = 1_000
    private static let maxStack = 20_000

    init(
        store: ErrorStoring = FileErrorStore(),
        signals: CrashSignalRecorder = CrashSignalRecorder(),
        metadata: ErrorMetadata = .current(),
        uploader: ((ErrorReportRequest) async -> Bool)? = nil,
        userIdProvider: @escaping () -> String? = { nil }
    ) {
        self.store = store
        self.signals = signals
        self.metadata = metadata
        self.uploader = uploader
        self.userIdProvider = userIdProvider
    }

    func configure(
        uploader: @escaping (ErrorReportRequest) async -> Bool,
        userIdProvider: @escaping () -> String?
    ) {
        lock.lock()
        self.uploader = uploader
        self.userIdProvider = userIdProvider
        lock.unlock()
    }

    /// Ставит обработчики и переносит накопленные сигналы в буфер.
    func install() {
        guard !installed else { return }
        installed = true

        Self.previousExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler { exception in
            ErrorReporter.shared.record(
                level: "CRASH",
                tag: "NSException",
                message: exception.reason,
                stack: exception.callStackSymbols.joined(separator: "\n")
            )
            Self.previousExceptionHandler?(exception)
        }

        signals.install()
        for message in signals.drain() {
            record(level: "CRASH", tag: "signal", message: message, stack: nil)
        }
    }

    /// Фоновая отправка накопленного; вызывается при старте и после входа.
    func uploadPending() {
        Task.detached(priority: .utility) { [weak self] in
            await self?.drain()
        }
    }

    func recordCaught(tag: String, error: Error) {
        record(
            level: "ERROR",
            tag: tag,
            message: error.localizedDescription,
            stack: Thread.callStackSymbols.joined(separator: "\n")
        )
    }

    static func logCaught(_ tag: String, _ error: Error) {
        shared.recordCaught(tag: tag, error: error)
    }

    func record(level: String, tag: String?, message: String?, stack: String?) {
        lock.lock()
        let userId = userIdProvider()
        lock.unlock()

        let event = ErrorEvent(
            level: level,
            tag: tag,
            message: message.map(ErrorSanitizer.sanitize).map { String($0.prefix(Self.maxMessage)) },
            stack: stack.map(ErrorSanitizer.sanitize).map { String($0.prefix(Self.maxStack)) },
            appVersion: metadata.appVersion,
            versionCode: metadata.versionCode,
            buildType: metadata.buildType,
            device: metadata.device,
            os: metadata.os,
            userId: userId
        )
        store.append(event)
    }

    func drain() async {
        lock.lock()
        guard !isDraining, let uploader else {
            lock.unlock()
            return
        }
        isDraining = true
        lock.unlock()
        defer {
            lock.lock()
            isDraining = false
            lock.unlock()
        }

        for _ in 0..<Self.maxBatches {
            let batch = store.pending(limit: Self.batchSize)
            guard !batch.isEmpty else { return }

            let request = ErrorReportRequest(events: batch, overflowed: store.overflowed)
            guard await uploader(request) else { return }

            store.remove(eventIds: Set(batch.map(\.eventId)))
            if let newest = batch.map(\.time).max() {
                store.lastUploadedAt = newest
            }
            if store.pending(limit: 1).isEmpty {
                store.overflowed = false
            }
        }
    }
}
