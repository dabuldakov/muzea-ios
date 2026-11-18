import XCTest
@testable import Muzea

final class LRUStoreTests: XCTestCase {

    func testEvictsOldestWhenLimitReached() {
        let store = LRUStore<String, Int>(limit: 2)
        store.set(1, for: "a")
        store.set(2, for: "b")
        store.set(3, for: "c")

        XCTAssertNil(store.value(for: "a"))
        XCTAssertEqual(store.value(for: "b"), 2)
        XCTAssertEqual(store.value(for: "c"), 3)
        XCTAssertEqual(store.all(), [2, 3])
    }

    func testUpdatingKeyMovesItToTheEnd() {
        let store = LRUStore<String, Int>(limit: 2)
        store.set(1, for: "a")
        store.set(2, for: "b")
        store.set(10, for: "a")
        store.set(3, for: "c")

        XCTAssertEqual(store.value(for: "a"), 10)
        XCTAssertNil(store.value(for: "b"))
        XCTAssertEqual(store.all(), [10, 3])
    }

    func testReplaceAndClear() {
        let store = LRUStore<String, Int>(limit: 3)
        store.set(1, for: "a")
        store.replace([("b", 2), ("c", 3)])

        XCTAssertFalse(store.contains("a"))
        XCTAssertEqual(store.all(), [2, 3])
        XCTAssertFalse(store.isEmpty())

        store.clear()
        XCTAssertTrue(store.isEmpty())
        XCTAssertTrue(store.all().isEmpty)
    }

    func testLimitIsAtLeastOne() {
        let store = LRUStore<String, Int>(limit: 0)
        store.set(1, for: "a")
        store.set(2, for: "b")

        XCTAssertEqual(store.all(), [2])
    }
}

final class DraftAndReactionStoreTests: XCTestCase {

    private func defaults() -> (UserDefaults, String) {
        let suite = "stores-\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    func testDraftSaveReadAndClear() {
        let (defaults, suite) = defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsChatDraftStore(defaults: defaults)

        store.save(chatUuid: "c-1", text: "  hello  ")
        XCTAssertEqual(store.draft(chatUuid: "c-1"), "  hello  ")

        store.save(chatUuid: "c-1", text: "   ")
        XCTAssertNil(store.draft(chatUuid: "c-1"))

        store.save(chatUuid: "c-2", text: "hi")
        store.clear(chatUuid: "c-2")
        XCTAssertNil(store.draft(chatUuid: "c-2"))
    }

    func testDraftIgnoresEmptyChatUuid() {
        let (defaults, suite) = defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsChatDraftStore(defaults: defaults)

        store.save(chatUuid: "", text: "hello")

        XCTAssertNil(store.draft(chatUuid: ""))
    }

    func testReactionHistoryPutsLatestFirstAndDeduplicates() {
        let (defaults, suite) = defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsReactionHistoryStore(defaults: defaults)

        store.record("👍")
        store.record("🔥")
        store.record("👍")

        XCTAssertEqual(store.recent().prefix(2).map { $0 }, ["👍", "🔥"])
    }

    func testReactionHistoryFallsBackToCatalog() {
        let (defaults, suite) = defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsReactionHistoryStore(defaults: defaults)

        XCTAssertEqual(store.recent(), Array(ReactionCatalog.all.prefix(ReactionCatalog.recentLimit)))
    }
}

final class CacheManagerTests: XCTestCase {

    private func makeDirectory(withFileSize size: Int) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(repeating: 1, count: size).write(to: directory.appendingPathComponent("file.bin"))
        return directory
    }

    func testReportsSizeAndClearsDirectories() async throws {
        let first = try makeDirectory(withFileSize: 100)
        let second = try makeDirectory(withFileSize: 50)
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        var actionCalled = false
        let manager = CacheManager(
            directories: [first, second],
            clearActions: [{ actionCalled = true }]
        )

        XCTAssertEqual(manager.totalSizeBytes(), 150)

        await manager.clear()

        XCTAssertEqual(manager.totalSizeBytes(), 0)
        XCTAssertTrue(actionCalled)
    }
}

final class AppRouterTests: XCTestCase {

    @MainActor
    func testChatLinkSelectsChatsTabAndTarget() {
        let router = AppRouter()

        let handled = router.handleURL(URL(string: "muzea://chat/c-1?title=Alice")!)

        XCTAssertTrue(handled)
        XCTAssertEqual(router.selectedTab, AppRouter.tabChats)
        XCTAssertEqual(router.chatTarget?.chatUuid, "c-1")
        XCTAssertEqual(router.chatTarget?.title, "Alice")
    }

    @MainActor
    func testNewsLinkSelectsNewsTab() {
        let router = AppRouter()

        XCTAssertTrue(router.handleURL(URL(string: "https://muzea.su/news/42")!))
        XCTAssertEqual(router.selectedTab, AppRouter.tabNews)
        XCTAssertEqual(router.newsTarget, 42)
    }

    @MainActor
    func testShareLinkSelectsChatsAndConsumesText() {
        let router = AppRouter()

        XCTAssertTrue(router.handleURL(URL(string: "muzea://share?text=hello%20world")!))
        XCTAssertEqual(router.selectedTab, AppRouter.tabChats)
        XCTAssertEqual(router.consumeSharedText(), "hello world")
        XCTAssertNil(router.consumeSharedText())
    }

    @MainActor
    func testUnknownLinkIsNotHandled() {
        let router = AppRouter()

        XCTAssertFalse(router.handleURL(URL(string: "https://example.com/chat/1")!))
        XCTAssertEqual(router.selectedTab, AppRouter.tabNews)
    }

    @MainActor
    func testPushRouteMovesTabs() {
        let router = AppRouter()

        router.handle(.news(7))
        XCTAssertEqual(router.selectedTab, AppRouter.tabNews)
        XCTAssertEqual(router.newsTarget, 7)

        router.handle(.chat(ChatPushTarget(chatUuid: "c-9", title: nil, avatarUrl: nil, messageUuid: nil)))
        XCTAssertEqual(router.selectedTab, AppRouter.tabChats)
        XCTAssertEqual(router.chatTarget?.chatUuid, "c-9")
    }
}

final class FilePendingAttachmentStoreTests: XCTestCase {

    private func makeStore() -> (FilePendingAttachmentStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-test-\(UUID().uuidString)", isDirectory: true)
        return (FilePendingAttachmentStore(root: root), root)
    }

    private func record(_ id: String, chat: String = "c-1") -> StoredPendingAttachment {
        StoredPendingAttachment(
            id: id,
            chatUuid: chat,
            fileName: "photo.jpg",
            mimeType: "image/jpeg",
            kind: "IMAGE",
            width: 10,
            height: 20,
            duration: nil,
            filePath: "",
            thumbnailPath: nil,
            uploaded: nil
        )
    }

    func testSaveLoadAndReadPayload() throws {
        let (store, root) = makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        try store.save(record: record("a"), data: Data([1, 2, 3]), thumbnail: Data([9, 9]))
        let loaded = store.load(chatUuid: "c-1")

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, "a")
        let fileURL = URL(fileURLWithPath: loaded[0].filePath)
        XCTAssertEqual(try Data(contentsOf: fileURL), Data([1, 2, 3]))
        let thumbnailPath = try XCTUnwrap(loaded[0].thumbnailPath)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: thumbnailPath)), Data([9, 9]))
    }

    func testUpdateUploadedStateAndRemove() throws {
        let (store, root) = makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        try store.save(record: record("a"), data: Data([1]), thumbnail: nil)
        var loaded = try XCTUnwrap(store.load(chatUuid: "c-1").first)
        loaded.uploaded = ChatAttachment(
            attachmentUuid: "u-1",
            fileName: "photo.jpg",
            fileUrl: nil,
            thumbnailUrl: nil,
            mp4Url: nil,
            fileSize: 1,
            mimeType: "image/jpeg",
            type: "IMAGE",
            width: nil,
            height: nil,
            duration: nil,
            gifKey: nil
        )
        store.update(loaded)

        XCTAssertEqual(store.load(chatUuid: "c-1").first?.uploaded?.attachmentUuid, "u-1")

        store.remove(id: "a")
        XCTAssertTrue(store.load(chatUuid: "c-1").isEmpty)
    }

    func testClearChatAndClearAll() throws {
        let (store, root) = makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        try store.save(record: record("a", chat: "c-1"), data: Data([1]), thumbnail: nil)
        try store.save(record: record("b", chat: "c-2"), data: Data([1]), thumbnail: nil)

        store.clear(chatUuid: "c-1")
        XCTAssertTrue(store.load(chatUuid: "c-1").isEmpty)
        XCTAssertEqual(store.load(chatUuid: "c-2").count, 1)

        store.clearAll()
        XCTAssertTrue(store.load(chatUuid: "c-2").isEmpty)
    }
}

final class AttachmentFileCacheTests: XCTestCase {

    func testDownloadsOnceAndReusesFile() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("attachment-cache-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = AttachmentFileCache(directory: directory)
        let repository = FakeAttachmentRepository()
        repository.downloadData = Data([7, 7, 7])

        let first = await cache.localURL(
            attachmentUuid: "a-1",
            fileName: "photo.jpg",
            repository: repository
        )
        let second = await cache.localURL(
            attachmentUuid: "a-1",
            fileName: "photo.jpg",
            repository: repository
        )

        XCTAssertEqual(repository.downloads, 1)
        let url = try XCTUnwrap(first)
        XCTAssertEqual(try Data(contentsOf: url), Data([7, 7, 7]))
        XCTAssertEqual(second, first)
    }

    func testMissingFileInvalidatesCache() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("attachment-cache-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = AttachmentFileCache(directory: directory)
        let repository = FakeAttachmentRepository()

        let cached = await cache.localURL(
            attachmentUuid: "a-1",
            fileName: "photo.jpg",
            repository: repository
        )
        let url = try XCTUnwrap(cached)
        try FileManager.default.removeItem(at: url)

        XCTAssertNil(cache.cachedURL(attachmentUuid: "a-1"))
    }
}

final class AuthErrorMapperTests: XCTestCase {

    private func map(_ error: Error) -> String {
        AuthErrorMapper.message(for: error)
    }

    func testTransportErrors() {
        XCTAssertEqual(map(APIError.transport(URLError(.notConnectedToInternet))), L10n.networkUnavailable)
        XCTAssertEqual(map(APIError.invalidURL), L10n.invalidURL)
        XCTAssertEqual(map(APIError.decoding(URLError(.badURL))), L10n.unexpectedResponse)
        XCTAssertEqual(map(APIError.unauthorized), L10n.sessionExpired)
    }

    func testServerCodes() {
        XCTAssertEqual(
            map(APIError.server(429, #"{"code":"otp_cooldown","message":"wait"}"#)),
            L10n.cooldown
        )
        XCTAssertEqual(
            map(APIError.server(409, #"{"code":"email_taken","message":"taken"}"#)),
            L10n.emailTaken
        )
        XCTAssertEqual(
            map(APIError.server(400, #"{"code":"otp_expired","message":"expired"}"#)),
            L10n.otpExpired
        )
        XCTAssertEqual(
            map(APIError.server(429, #"{"code":"unknown","message":null}"#)),
            L10n.rateLimited
        )
        XCTAssertEqual(
            map(APIError.server(500, "plain text")),
            L10n.serverCode(500)
        )
        XCTAssertEqual(
            map(APIError.server(403, "forbidden")),
            L10n.unauthorized
        )
    }

    func testValidationFallbackUsesServerMessage() {
        XCTAssertEqual(
            map(APIError.server(400, #"{"code":"validation_error","message":"bad username"}"#)),
            "bad username"
        )
    }
}

final class RouterTests: XCTestCase {

    @MainActor
    func testPushBackAndPopToRoot() {
        let router = Router()

        router.push(.newsDetail(1))
        router.push(.videoDetail(Video(
            id: 2,
            title: "V",
            description: nil,
            url: "/v.mp4",
            thumbnailUrl: nil,
            fileSize: nil,
            durationSeconds: nil,
            views: 0,
            likes: nil,
            likedByMe: nil,
            uploadedBy: "me",
            uploadedAt: "2026-01-01T00:00:00"
        )))
        XCTAssertEqual(router.path.count, 2)

        router.back()
        XCTAssertEqual(router.path.count, 1)

        router.popToRoot()
        XCTAssertEqual(router.path.count, 0)

        // На пустом стеке ничего не падает.
        router.back()
        router.popToRoot()
        XCTAssertEqual(router.path.count, 0)
    }
}

final class AudioAndWaveformTests: XCTestCase {

    @MainActor
    func testAudioPlaybackIgnoresAttachmentWithoutUUID() async {
        let center = AudioPlaybackCenter()
        let attachment = ChatAttachment(
            attachmentUuid: nil,
            fileName: "voice.m4a",
            fileUrl: nil,
            thumbnailUrl: nil,
            mp4Url: nil,
            fileSize: nil,
            mimeType: "audio/mp4",
            type: "AUDIO",
            width: nil,
            height: nil,
            duration: 3,
            gifKey: nil
        )

        await center.toggle(id: "a", attachment: attachment, repository: FakeAttachmentRepository())

        XCTAssertFalse(center.isPlaying("a"))
        XCTAssertNil(center.playingId)
        center.stop()
    }

    @MainActor
    func testVideoNoteLimits() {
        XCTAssertFalse(VideoNoteLimits.isValid(duration: 0.5))
        XCTAssertTrue(VideoNoteLimits.isValid(duration: 1))
        XCTAssertTrue(VideoNoteLimits.isValid(duration: 60))
        XCTAssertTrue(VideoNoteLimits.isValid(duration: 61))
        XCTAssertFalse(VideoNoteLimits.isValid(duration: 62))
        XCTAssertEqual(VideoNoteLimits.clampedDuration(-5), 0)
        XCTAssertEqual(VideoNoteLimits.clampedDuration(100), 60)
    }

    func testWaveformProviderReturnsNilForBrokenAudio() async {
        let attachment = ChatAttachment(
            attachmentUuid: "broken",
            fileName: "voice.m4a",
            fileUrl: nil,
            thumbnailUrl: nil,
            mp4Url: nil,
            fileSize: 3,
            mimeType: "audio/mp4",
            type: "AUDIO",
            width: nil,
            height: nil,
            duration: 1,
            gifKey: nil
        )
        let repository = FakeAttachmentRepository()
        repository.downloadData = Data([0, 1, 2, 3])

        let waveform = await WaveformProvider.shared.waveform(
            for: attachment,
            repository: repository
        )

        XCTAssertNil(waveform)
    }

    func testWaveformPeakSamplesForMissingFile() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).m4a")

        let samples = await WaveformProvider.peakSamples(url: url)

        XCTAssertTrue(samples.isEmpty)
    }
}
