import XCTest
@testable import Muzea

final class GifParsingTests: XCTestCase {

    private let json = """
    {
      "result": true,
      "data": {
        "data": [
          {
            "id": 42,
            "slug": "party-cat",
            "title": "Party cat",
            "file": {
              "hd": {
                "webp": {"url": "https://cdn/hd.webp", "width": 480, "height": 270},
                "mp4": {"url": "https://cdn/hd.mp4", "width": 480, "height": 270}
              },
              "sm": {
                "jpg": {"url": "https://cdn/sm.jpg", "width": 120, "height": 68},
                "webp": {"url": "https://cdn/sm.webp", "width": 120, "height": 68}
              }
            }
          }
        ]
      }
    }
    """

    func testMapsKlipyItemToGif() throws {
        let gifs = KlipyGifRepository.parse(Data(json.utf8))

        let gif = try XCTUnwrap(gifs.first)
        XCTAssertEqual(gif.provider, "klipy")
        XCTAssertEqual(gif.providerGifId, "party-cat")
        XCTAssertEqual(gif.url, "https://cdn/hd.webp")
        XCTAssertEqual(gif.previewUrl, "https://cdn/sm.jpg")
        XCTAssertEqual(gif.mp4Url, "https://cdn/hd.mp4")
        XCTAssertEqual(gif.width, 480)
        XCTAssertEqual(gif.height, 270)
    }

    func testSkipsItemsWithoutMedia() {
        let broken = #"{"data":{"data":[{"id":1,"slug":"empty"}]}}"#
        XCTAssertTrue(KlipyGifRepository.parse(Data(broken.utf8)).isEmpty)
    }

    func testServerGifDTOResolvesRelativeURLs() throws {
        let json = """
        {"gifUuid":"g1","provider":"klipy","providerGifId":"42","title":"Cat",
         "url":"/api/gifs/file/a.webp","previewUrl":"/api/gifs/file/a.jpg",
         "mp4Url":null,"width":10,"height":20}
        """
        let gif = try TestSupport.decode(GifDTO.self, json).toDomain()

        XCTAssertEqual(gif.gifKey, "g1")
        XCTAssertEqual(gif.url, "https://chat-muzea.su/api/gifs/file/a.webp")
        XCTAssertEqual(gif.previewUrl, "https://chat-muzea.su/api/gifs/file/a.jpg")
    }

    func testGifCacheKeepsFreshAndStale() async {        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gif-cache-\(UUID().uuidString).json")
        let cache = GifCache(fileURL: url)
        let gif = Gif(
            provider: "klipy",
            providerGifId: "1",
            title: "t",
            url: "u",
            previewUrl: nil,
            mp4Url: nil,
            width: nil,
            height: nil,
            gifKey: nil
        )

        await cache.put(key: "k", items: [gif])

        let fresh = await cache.fresh(key: "k", ttl: 60)
        let stale = await cache.stale(key: "k")
        let other = await cache.fresh(key: "other", ttl: 60)
        XCTAssertEqual(fresh?.first, gif)
        XCTAssertEqual(stale?.first, gif)
        XCTAssertNil(other)
        await cache.clearAll()
        let cleared = await cache.stale(key: "k")
        XCTAssertNil(cleared)
    }
}

final class KlipyGifRepositoryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testSearchUsesKlipyEndpointAndCachesFirstPage() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gif-cache-\(UUID().uuidString).json")
        let cache = GifCache(fileURL: url)
        let repository = KlipyGifRepository(
            apiKey: "test-key",
            session: TestSupport.session(),
            cache: cache
        )
        MockURLProtocol.handler = { request in
            (
                MockURLProtocol.response(for: request),
                Data(#"{"data":{"data":[{"id":1,"slug":"s","file":{"sm":{"webp":{"url":"https://cdn/1.webp"}}}}]}}"#.utf8)
            )
        }

        let first = await repository.search(query: "cat", page: 0, size: 24)
        let second = await repository.search(query: "cat", page: 0, size: 24)

        XCTAssertEqual(first.first?.providerGifId, "s")
        XCTAssertEqual(second.first?.providerGifId, "s")
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
        let request = MockURLProtocol.requests.first
        XCTAssertTrue(request?.url?.path.contains("test-key") ?? false)
        XCTAssertTrue(request?.url?.path.contains("search") ?? false)
        XCTAssertTrue(request?.url?.query?.contains("q=cat") ?? false)
    }

    func testBlankKeyDisablesSearchWithoutRequest() async {
        let cache = GifCache(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("gif-cache-\(UUID().uuidString).json"))
        let repository = KlipyGifRepository(
            apiKey: "",
            session: TestSupport.session(),
            cache: cache
        )

        let result = await repository.search(query: "", page: 0, size: 24)

        XCTAssertTrue(result.isEmpty)
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }
}

final class ServerGifRepositoryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func repository() -> KlipyGifRepository {
        let store = TestSupport.makeStore()
        store.token = "access"
        store.chatUserUuid = "me"
        let client = TestSupport.chatClient(tokenStore: store)
        let auth = ChatAuthorization(
            client: client,
            auth: ChatAuthManager(client: client, store: store)
        )
        return KlipyGifRepository(
            apiKey: "",
            session: TestSupport.session(),
            cache: GifCache(fileURL: URL(fileURLWithPath: "/tmp/gif-test-\(UUID().uuidString).json")),
            auth: auth
        )
    }

    func testRecentUsesServerEndpoint() async {
        MockURLProtocol.handler = { request in
            (
                MockURLProtocol.response(for: request),
                Data(#"[{"gifUuid":"g1","provider":"klipy","providerGifId":"p1","url":"/api/gifs/file/a.webp"}]"#.utf8)
            )
        }

        let gifs = await repository().recent(page: 0, size: 30)

        XCTAssertEqual(gifs.first?.gifKey, "g1")
        XCTAssertEqual(gifs.first?.url, "https://chat-muzea.su/api/gifs/file/a.webp")
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/gifs/recent")
    }

    func testChatUsesChatEndpoint() async {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), Data(#"[{"provider":"klipy","providerGifId":"p1","url":"https://cdn/a.webp"}]"#.utf8))
        }

        _ = await repository().chat(chatUuid: "c1", page: 0, size: 30)

        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/gifs/chat/c1")
    }
}

@MainActor
final class GifSearchViewModelTests: XCTestCase {
    private let gif = Gif(
        provider: "klipy",
        providerGifId: "1",
        title: nil,
        url: "u",
        previewUrl: nil,
        mp4Url: nil,
        width: nil,
        height: nil,
        gifKey: nil
    )

    func testLoadsRecentThenChatThenSearch() async {
        let repository = FakeGifRepository()
        repository.recentGifs = [gif]
        repository.chatGifs = [gif]
        repository.gifs = [gif]
        let viewModel = GifSearchViewModel(repository: repository, chatUuid: "c1")

        await viewModel.loadIfNeeded()
        XCTAssertEqual(viewModel.tab, .recent)
        XCTAssertEqual(viewModel.gifs.count, 1)

        await viewModel.select(.chat)
        XCTAssertEqual(viewModel.tab, .chat)
        XCTAssertEqual(viewModel.gifs.count, 1)

        await viewModel.select(.search)
        await viewModel.search(query: "cat")
        XCTAssertEqual(repository.queries.last, "cat")
        XCTAssertEqual(viewModel.gifs.count, 1)
    }

    func testChatTabWithoutChatDoesNotLoad() async {
        let repository = FakeGifRepository()
        let viewModel = GifSearchViewModel(repository: repository)

        await viewModel.select(.chat)

        XCTAssertTrue(viewModel.gifs.isEmpty)
        XCTAssertFalse(viewModel.hasMore)
    }}
