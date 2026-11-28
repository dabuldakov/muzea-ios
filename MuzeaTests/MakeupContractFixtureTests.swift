import XCTest
@testable import Muzea

/// Контракт makeup-сервиса на общих фикстурах. Android-тесты используют те же
/// JSON, поэтому расхождение полей ловится на обеих платформах.
final class MakeupContractFixtureTests: XCTestCase {

    private func fixture(_ path: String) throws -> Data {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/fixtures")
        return try Data(contentsOf: root.appendingPathComponent(path))
    }

    private func decode<T: Decodable>(_ type: T.Type, _ path: String) throws -> T {
        try JSONDecoder().decode(T.self, from: fixture(path))
    }

    func testNewsPageMapsToDomainWithRelatedVideo() throws {
        let dto = try decode(PageResponse<NewsDTO>.self, "makeup/news_page.json")
        let page = dto.toDomain { $0.toDomain() }

        XCTAssertEqual(page.content.count, 1)
        let news = page.content[0]
        XCTAssertEqual(news.id, 54)
        XCTAssertEqual(news.author, "dabuldakov")
        XCTAssertEqual(news.relatedVideo?.id, 18)
        XCTAssertEqual(
            news.relatedVideo?.fullVideoURL?.absoluteString,
            "https://api.muzea.su/api/videos/stream/video.mp4"
        )
    }

    func testNewsWithoutVideoAndMaskedAuthor() throws {
        let news = try decode(NewsDTO.self, "makeup/news.json").toDomain()

        XCTAssertNil(news.relatedVideo)
        XCTAssertNil(news.imageUrl)
        XCTAssertEqual(news.author, "Удалённый пользователь")
    }

    func testVideosMapAndResolveURLs() throws {
        let videos = try decode([VideoDTO].self, "makeup/videos.json").map { $0.toDomain() }

        XCTAssertEqual(videos.count, 1)
        let video = videos[0]
        XCTAssertEqual(video.durationSeconds, 12)
        XCTAssertEqual(video.likes, 3)
        XCTAssertEqual(
            video.fullVideoURL?.absoluteString,
            "https://api.muzea.su/api/videos/stream/video.mp4"
        )
        XCTAssertEqual(
            video.fullThumbnailURL?.absoluteString,
            "https://api.muzea.su/api/videos/thumbnail/video.jpeg"
        )
    }

    func testUserMapsWithoutEmail() throws {
        let user = try decode(UserDTO.self, "makeup/user.json").toDomain()

        XCTAssertEqual(user.id, 7)
        XCTAssertEqual(user.userName, "dabuldakov")
        XCTAssertNil(user.email)
        XCTAssertEqual(user.enabled, true)
    }

    func testNewsCreatedResponse() throws {
        let created = try decode(NewsCreateResponse.self, "makeup/news_created.json")
        XCTAssertEqual(created.id, 55)
    }
}
