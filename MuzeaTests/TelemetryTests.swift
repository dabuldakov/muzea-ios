import Darwin
import XCTest
@testable import Muzea

final class ErrorSanitizerTests: XCTestCase {

    func testRemovesEmailPhoneAndTokens() {
        let input = """
        user dabuldakov@mail.ru failed, call +7 (912) 345-67-89, \
        Authorization: Bearer abc.def.ghi token=secret123 password: hunter2
        """
        let output = ErrorSanitizer.sanitize(input)

        XCTAssertFalse(output.contains("dabuldakov@mail.ru"))
        XCTAssertFalse(output.contains("345-67-89"))
        XCTAssertFalse(output.contains("secret123"))
        XCTAssertFalse(output.contains("hunter2"))
        XCTAssertTrue(output.contains("[email]"))
        XCTAssertTrue(output.contains("[phone]"))
        XCTAssertTrue(output.contains("[token]"))
    }

    func testBearerTokenIsReplaced() {
        let jwt = "aaaa.bbbb.cccc.dddd.eeee.ffff.gggg.hhhh"
        let output = ErrorSanitizer.sanitize("Authorization: Bearer \(jwt)")
        XCTAssertFalse(output.contains(jwt))
        XCTAssertTrue(output.contains("Bearer [token]"))
    }

    func testPlainTextIsUnchanged() {
        XCTAssertEqual(ErrorSanitizer.sanitize("Connection reset by peer"), "Connection reset by peer")
    }
}

final class FileErrorStoreTests: XCTestCase {

    private func makeStore(maxBytes: Int64 = FileErrorStore.defaultMaxBytes) -> (FileErrorStore, URL, UserDefaults, String) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("error-store-\(UUID().uuidString)", isDirectory: true)
        let suite = "error-store-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (
            FileErrorStore(
                fileURL: root.appendingPathComponent("errors.jsonl"),
                defaults: defaults,
                maxBytes: maxBytes
            ),
            root,
            defaults,
            suite
        )
    }

    private func event(_ id: String) -> ErrorEvent {
        ErrorEvent(
            eventId: id,
            level: "ERROR",
            tag: "Test",
            message: "boom",
            stack: nil,
            appVersion: "1.0",
            versionCode: 1,
            buildType: "debug",
            device: "iPhone",
            os: "iOS 18",
            userId: nil
        )
    }

    func testAppendPendingAndRemove() {
        let (store, root, defaults, suite) = makeStore()
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: suite)
        }
        store.append(event("a"))
        store.append(event("b"))

        XCTAssertEqual(store.pending(limit: 10).map(\.eventId), ["a", "b"])

        store.remove(eventIds: ["a"])
        XCTAssertEqual(store.pending(limit: 10).map(\.eventId), ["b"])
        XCTAssertGreaterThan(store.sizeBytes(), 0)
    }

    func testOverflowStopsWritesAndSetsFlag() {
        let (store, root, defaults, suite) = makeStore(maxBytes: 10)
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: suite)
        }

        store.append(event("a"))
        store.append(event("b"))

        XCTAssertTrue(store.overflowed)
        XCTAssertEqual(store.pending(limit: 10).map(\.eventId), ["a"])
    }

    func testClearRemovesBufferAndOverflow() {
        let (store, root, defaults, suite) = makeStore()
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: suite)
        }
        store.append(event("a"))
        store.overflowed = true

        store.clear()

        XCTAssertTrue(store.pending(limit: 10).isEmpty)
        XCTAssertFalse(store.overflowed)
    }

    func testLastUploadedAtPersists() {
        let (store, root, defaults, suite) = makeStore()
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: suite)
        }

        store.lastUploadedAt = "2026-01-01T00:00:00Z"

        XCTAssertEqual(store.lastUploadedAt, "2026-01-01T00:00:00Z")
    }
}

final class CrashSignalRecorderTests: XCTestCase {

    func testDrainConvertsRawSignals() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("crash-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: url) }
        var value = SIGSEGV
        let data = withUnsafeBytes(of: &value) { Data($0) }
        try data.write(to: url)
        let recorder = CrashSignalRecorder(pendingURL: url)

        XCTAssertEqual(recorder.drain(), ["Fatal signal \(SIGSEGV)"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}

private final class FakeErrorStore: ErrorStoring {
    var overflowed = false
    var lastUploadedAt: String?
    var events: [ErrorEvent] = []

    func append(_ event: ErrorEvent) { events.append(event) }
    func pending(limit: Int) -> [ErrorEvent] { Array(events.prefix(limit)) }
    func remove(eventIds: Set<String>) { events.removeAll { eventIds.contains($0.eventId) } }
    func sizeBytes() -> Int64 { Int64(events.count) }
    func clear() {
        events.removeAll()
        overflowed = false
    }
}

final class ErrorReporterTests: XCTestCase {

    private let metadata = ErrorMetadata(
        appVersion: "1.1",
        versionCode: 5,
        buildType: "debug",
        device: "iPhone",
        os: "iOS 18"
    )

    func testCaughtErrorIsSanitizedAndTruncated() {
        let store = FakeErrorStore()
        let reporter = ErrorReporter(
            store: store,
            signals: CrashSignalRecorder(pendingURL: URL(fileURLWithPath: "/dev/null")),
            metadata: metadata,
            userIdProvider: { "u-1" }
        )

        reporter.recordCaught(
            tag: "Chat",
            error: NSError(
                domain: "test",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "mail me@example.com"]
            )
        )

        let event = store.events.first
        XCTAssertEqual(event?.level, "ERROR")
        XCTAssertEqual(event?.tag, "Chat")
        XCTAssertEqual(event?.message, "mail [email]")
        XCTAssertEqual(event?.userId, "u-1")
        XCTAssertNotNil(event?.stack)
    }

    func testDrainUploadsAndClearsSentEvents() async {
        let store = FakeErrorStore()
        store.events = [makeEvent("a"), makeEvent("b")]
        store.overflowed = true
        var uploaded: [Int] = []
        let reporter = ErrorReporter(
            store: store,
            signals: CrashSignalRecorder(pendingURL: URL(fileURLWithPath: "/dev/null")),
            metadata: metadata,
            uploader: { request in
                uploaded.append(request.events.count)
                return true
            }
        )

        await reporter.drain()

        XCTAssertEqual(uploaded, [2])
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertFalse(store.overflowed)
        XCTAssertEqual(store.lastUploadedAt, "2026-01-01T00:00:00Z")
    }

    func testFailedUploadKeepsEvents() async {
        let store = FakeErrorStore()
        store.events = [makeEvent("a")]
        let reporter = ErrorReporter(
            store: store,
            signals: CrashSignalRecorder(pendingURL: URL(fileURLWithPath: "/dev/null")),
            metadata: metadata,
            uploader: { _ in false }
        )

        await reporter.drain()

        XCTAssertEqual(store.events.map(\.eventId), ["a"])
        XCTAssertNil(store.lastUploadedAt)
    }

    func testDrainSendsBatchesUpToLimit() async {
        let store = FakeErrorStore()
        store.events = (0..<150).map { makeEvent("e-\($0)") }
        var uploaded: [Int] = []
        let reporter = ErrorReporter(
            store: store,
            signals: CrashSignalRecorder(pendingURL: URL(fileURLWithPath: "/dev/null")),
            metadata: metadata,
            uploader: { request in
                uploaded.append(request.events.count)
                return true
            }
        )

        await reporter.drain()

        XCTAssertEqual(uploaded, [100, 50])
        XCTAssertTrue(store.events.isEmpty)
    }

    func testMessageAndStackAreTruncated() {
        let store = FakeErrorStore()
        let reporter = ErrorReporter(
            store: store,
            signals: CrashSignalRecorder(pendingURL: URL(fileURLWithPath: "/dev/null")),
            metadata: metadata
        )

        reporter.record(
            level: "ERROR",
            tag: "Long",
            message: String(repeating: "m", count: 5_000),
            stack: String(repeating: "s", count: 30_000)
        )

        XCTAssertEqual(store.events.first?.message?.count, 1_000)
        XCTAssertEqual(store.events.first?.stack?.count, 20_000)
    }

    func testRequestEncodingMatchesServerContract() throws {
        let event = makeEvent("a")
        let request = ErrorReportRequest(events: [event], overflowed: false)
        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["overflowed"] as? Bool, false)
        let events = try XCTUnwrap(json["events"] as? [[String: Any]])
        XCTAssertEqual(events.first?["eventId"] as? String, "a")
        XCTAssertEqual(events.first?["level"] as? String, "ERROR")
        XCTAssertEqual(events.first?["appVersion"] as? String, "1.0")
        XCTAssertEqual(events.first?["versionCode"] as? Int, 1)
        XCTAssertEqual(events.first?["os"] as? String, "iOS 18")
    }

    private func makeEvent(_ id: String) -> ErrorEvent {
        ErrorEvent(
            eventId: id,
            time: "2026-01-01T00:00:00Z",
            level: "ERROR",
            tag: "Test",
            message: "boom",
            stack: nil,
            appVersion: "1.0",
            versionCode: 1,
            buildType: "debug",
            device: "iPhone",
            os: "iOS 18",
            userId: nil
        )
    }
}

final class LinkPreviewSecurityTests: XCTestCase {

    func testIPv4MappedIPv6IsBlocked() {
        XCTAssertTrue(LinkPreviewSafety.isBlockedHost("::ffff:127.0.0.1"))
        XCTAssertTrue(LinkPreviewSafety.isBlockedHost("::ffff:10.1.2.3"))
        XCTAssertTrue(LinkPreviewSafety.isBlockedHost("::ffff:192.168.1.1"))
        XCTAssertTrue(LinkPreviewSafety.isBlockedHost("::127.0.0.1"))
        XCTAssertFalse(LinkPreviewSafety.isBlockedHost("::ffff:8.8.8.8"))
    }

    func testMappedLocalURLIsUnsafe() {
        XCTAssertFalse(LinkPreviewSafety.isSafe(URL(string: "http://[::ffff:127.0.0.1]/secret")!))
    }

    func testPublicURLsAreSafe() {
        XCTAssertTrue(LinkPreviewSafety.isSafe(URL(string: "https://8.8.8.8/chat/1")!))
        XCTAssertFalse(LinkPreviewSafety.isSafe(URL(string: "file:///etc/passwd")!))
        XCTAssertFalse(LinkPreviewSafety.isSafe(URL(string: "http://localhost:8080")!))
        XCTAssertFalse(LinkPreviewSafety.isSafe(URL(string: "http://169.254.169.254/latest")!))
    }

    func testErrorBufferIsClearedOnLogout() {
        let store = FakeErrorStore()
        store.events = [
            ErrorEvent(
                eventId: "a",
                level: "ERROR",
                tag: nil,
                message: "boom",
                stack: nil,
                appVersion: "1",
                versionCode: 1,
                buildType: "debug",
                device: "iPhone",
                os: "iOS",
                userId: "u-1"
            )
        ]
        let reporter = ErrorReporter(
            store: store,
            signals: CrashSignalRecorder(pendingURL: URL(fileURLWithPath: "/dev/null")),
            metadata: ErrorMetadata(
                appVersion: "1",
                versionCode: 1,
                buildType: "debug",
                device: "iPhone",
                os: "iOS"
            )
        )

        reporter.clearPending()

        XCTAssertTrue(store.events.isEmpty)
        XCTAssertFalse(store.overflowed)
    }
}
