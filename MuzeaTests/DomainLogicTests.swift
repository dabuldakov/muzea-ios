import XCTest
@testable import Muzea

/// Чистая логика: редьюсер сообщений, use-case приватного чата, кэши и view-state.
final class ChatMessageReducerTests: XCTestCase {

    func testSeedSortsAscendingAndPushesUndatedToEnd() {
        let reducer = ChatMessageReducer()
        let input = [
            TestData.message("m3", createdAt: "2026-01-01T00:00:03"),
            TestData.message("m1", createdAt: "2026-01-01T00:00:01"),
            TestData.message("mLocal", createdAt: nil),
            TestData.message("m2", createdAt: "2026-01-01T00:00:02")
        ]

        let result = reducer.seed(input)

        XCTAssertEqual(result.map(\.messageUuid), ["m1", "m2", "m3", "mLocal"])
    }

    func testMergeKeepsCurrentAndDropsServerEcho() {
        let reducer = ChatMessageReducer()
        let local = TestData.message("local-1", text: "hi", createdAt: nil)
        reducer.applyServerEcho(
            current: [local],
            localUuid: "local-1",
            serverMessage: TestData.message("server-1", text: "hi", createdAt: "2026-01-01T00:00:01")
        )

        let merged = reducer.merge(
            current: [local],
            incoming: [
                TestData.message("server-1", text: "hi", createdAt: "2026-01-01T00:00:01"),
                TestData.message("server-2", text: "other", createdAt: "2026-01-01T00:00:02")
            ]
        )

        XCTAssertEqual(merged.map(\.messageUuid), ["local-1", "server-2"])
    }

    func testApplyServerEchoKeepsLocalUuidAndContent() {
        let reducer = ChatMessageReducer()
        let local = TestData.message("local-1", text: "hi", createdAt: nil)

        let result = reducer.applyServerEcho(
            current: [local],
            localUuid: "local-1",
            serverMessage: TestData.message("server-1", text: "hi!", createdAt: "2026-01-01T00:00:01")
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].messageUuid, "local-1")
        XCTAssertEqual(result[0].text, "hi!")
    }

    func testMergeExistingWinsOverIncoming() {
        let reducer = ChatMessageReducer()
        let current = TestData.message("m1", text: "local")
        let merged = reducer.merge(current: [current], incoming: [TestData.message("m1", text: "server")])

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].text, "local")
    }
}

final class OpenPrivateChatUseCaseTests: XCTestCase {

    func testReturnsExistingChatWithoutCreating() async throws {
        let chatRepository = FakeChatRepository()
        chatRepository.privateChats["u-1"] = TestData.chat("existing")
        let useCase = OpenPrivateChatUseCase(repository: chatRepository)

        let chat = try await useCase(userUuid: "u-1")

        XCTAssertEqual(chat.chatUuid, "existing")
        XCTAssertTrue(chatRepository.createdPrivateChats.isEmpty)
    }

    func testCreatesChatWhenNoneExists() async throws {
        let chatRepository = FakeChatRepository()
        let useCase = OpenPrivateChatUseCase(repository: chatRepository)

        let chat = try await useCase(userUuid: "u-2")

        XCTAssertEqual(chat.chatUuid, "created-u-2")
        XCTAssertEqual(chatRepository.createdPrivateChats, ["u-2"])
    }
}

final class MemoryCachesTests: XCTestCase {

    func testChatListCacheRoundTripAndDedup() {
        let cache = ChatListCache()
        cache.put([TestData.chat("a"), TestData.chat("b"), TestData.chat("a", title: "dup")])

        XCTAssertTrue(cache.has())
        XCTAssertEqual(cache.get().count, 2)

        cache.clear()
        XCTAssertFalse(cache.has())
    }

    func testChatMessagesCacheEvictsOldestChat() {
        let cache = ChatMessagesCache()
        for index in 0..<51 {
            cache.put(chatUuid: "c-\(index)", list: [TestData.message("m-\(index)")])
        }

        XCTAssertFalse(cache.has(chatUuid: "c-0"))
        XCTAssertTrue(cache.has(chatUuid: "c-50"))
        XCTAssertEqual(cache.get(chatUuid: "c-50").count, 1)
    }

    func testPrivateChatCacheIgnoresBlankUser() {
        let cache = PrivateChatCache()
        cache.put(userUuid: "   ", chat: TestData.chat("x"))
        XCTAssertNil(cache.get(userUuid: "   "))

        cache.put(userUuid: "u-1", chat: TestData.chat("x"))
        XCTAssertEqual(cache.get(userUuid: "u-1")?.chatUuid, "x")
    }

    func testVideoListCacheKeepsInsertionOrder() {
        let cache = VideoListCache()
        cache.put([
            VideoResponse(id: 2, title: "B", description: nil, url: "", thumbnailUrl: nil, fileSize: nil, durationSeconds: nil, views: 0, likes: nil, likedByMe: nil, uploadedBy: "me", uploadedAt: ""),
            VideoResponse(id: 1, title: "A", description: nil, url: "", thumbnailUrl: nil, fileSize: nil, durationSeconds: nil, views: 0, likes: nil, likedByMe: nil, uploadedBy: "me", uploadedAt: "")
        ])

        XCTAssertEqual(cache.get().map(\.id), [2, 1])
    }
}

final class ChatListViewStateTests: XCTestCase {

    private func state(_ chats: [ChatResponse], loading: Bool, error: String?) -> ChatListUiState {
        ChatListUiState(chats: chats, isLoading: loading, error: error)
    }

    func testListWhenChatsPresent() {
        XCTAssertEqual(state([TestData.chat("a")], loading: false, error: nil).viewState, .list)
    }

    func testLoadingWhenEmptyAndLoading() {
        XCTAssertEqual(state([], loading: true, error: nil).viewState, .loading)
    }

    func testErrorWhenEmptyAndFailed() {
        XCTAssertEqual(state([], loading: false, error: "boom").viewState, .error)
    }

    func testEmptyWhenNoDataNoErrorNotLoading() {
        XCTAssertEqual(state([], loading: false, error: nil).viewState, .empty)
    }
}
