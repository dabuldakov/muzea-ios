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

    func testGifCacheKeepsFreshAndStale() async {
        let url = FileManager.default.temporaryDirectory
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

@MainActor
final class GifSearchViewModelTests: XCTestCase {

    func testLoadIfNeededUsesTrendingAndSearchUsesQuery() async {
        let repository = FakeGifRepository()
        repository.gifs = [
            Gif(
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
        ]
        let viewModel = GifSearchViewModel(repository: repository)

        await viewModel.loadIfNeeded()
        await viewModel.search(query: "cat")

        XCTAssertEqual(repository.queries, ["", "cat"])
        XCTAssertEqual(viewModel.gifs.count, 1)
        XCTAssertFalse(viewModel.isLoading)
    }
}
