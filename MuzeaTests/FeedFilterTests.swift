import XCTest
@testable import Muzea

/// Зеркалит Android `NewsFeedFilterTest` и `VideoFeedFilterTest`.
final class FeedFilterTests: XCTestCase {

    // MARK: - News

    private func news(id: Int64, author: String) -> NewsResponse {
        NewsResponse(
            id: id,
            title: "Title \(id)",
            content: "Content \(id)",
            imageUrl: nil,
            relatedVideo: nil,
            author: author,
            publishedAt: "2026-01-01T00:00:00"
        )
    }

    private lazy var newsFeed = [
        news(id: 1, author: "dabuldakov"),
        news(id: 2, author: "maria"),
        news(id: 3, author: "stranger"),
        news(id: 4, author: "vovan"),
        news(id: 5, author: " DABULDAKOV ")
    ]

    func testNewsKeepsContactsAndSelf() {
        let result = NewsFeedFilter.filter(newsFeed, contactUsernames: ["dabuldakov"], ownUsername: "vovan")
        XCTAssertEqual(result.map(\.id), [1, 4])
    }

    func testNewsTrimsContactUsernames() {
        let result = NewsFeedFilter.filter(newsFeed, contactUsernames: ["  dabuldakov  "], ownUsername: nil)
        XCTAssertEqual(result.map(\.id), [1])
    }

    func testNewsMatchingIsCaseSensitive() {
        let result = NewsFeedFilter.filter(newsFeed, contactUsernames: ["dabuldakov"], ownUsername: nil)
        XCTAssertEqual(result.map(\.id), [1])
    }

    func testNewsShowsOnlyOwnWhenContactsEmpty() {
        let result = NewsFeedFilter.filter(newsFeed, contactUsernames: [], ownUsername: "vovan")
        XCTAssertEqual(result.map(\.id), [4])
    }

    func testNewsReturnsEmptyWithoutContactsAndSelf() {
        let result = NewsFeedFilter.filter(newsFeed, contactUsernames: [], ownUsername: nil)
        XCTAssertTrue(result.isEmpty)
    }

    func testNewsTrimsOwnUsername() {
        let result = NewsFeedFilter.filter(newsFeed, contactUsernames: [], ownUsername: "  vovan  ")
        XCTAssertEqual(result.map(\.id), [4])
    }

    // MARK: - Video

    private func video(id: Int64, uploadedBy: String) -> VideoResponse {
        VideoResponse(
            id: id,
            title: "Title \(id)",
            description: nil,
            url: "https://example.com/video\(id)",
            thumbnailUrl: nil,
            fileSize: nil,
            duration: nil,
            views: 0,
            likes: nil,
            uploadedBy: uploadedBy,
            uploadedAt: "2026-01-01T00:00:00"
        )
    }

    private lazy var videoFeed = [
        video(id: 1, uploadedBy: "dabuldakov"),
        video(id: 2, uploadedBy: "maria"),
        video(id: 3, uploadedBy: "stranger"),
        video(id: 4, uploadedBy: "vovan"),
        video(id: 5, uploadedBy: "VOVAN"),
        video(id: 6, uploadedBy: "  vovan  ")
    ]

    func testVideoKeepsOnlyOwn() {
        let result = VideoFeedFilter.filter(videoFeed, ownUsername: "vovan")
        XCTAssertEqual(result.map(\.id), [4, 6])
    }

    func testVideoMatchingIsCaseSensitive() {
        let result = VideoFeedFilter.filter(videoFeed, ownUsername: "VOVAN")
        XCTAssertEqual(result.map(\.id), [5])
    }

    func testVideoTrimsOwnUsername() {
        let result = VideoFeedFilter.filter(videoFeed, ownUsername: "  vovan  ")
        XCTAssertEqual(result.map(\.id), [4, 6])
    }

    func testVideoReturnsEmptyForNilOrBlankUsername() {
        XCTAssertTrue(VideoFeedFilter.filter(videoFeed, ownUsername: nil).isEmpty)
        XCTAssertTrue(VideoFeedFilter.filter(videoFeed, ownUsername: "   ").isEmpty)
    }

    func testVideoReturnsEmptyWhenNobodyMatches() {
        XCTAssertTrue(VideoFeedFilter.filter(videoFeed, ownUsername: "nobody").isEmpty)
    }
}