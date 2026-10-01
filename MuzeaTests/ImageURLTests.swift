import XCTest
@testable import Muzea

/// Зеркалит Android `MediaUrlTest`.
final class ImageURLTests: XCTestCase {

    func testAbsoluteSameDomainURLIsReturnedUnchanged() {
        let url = "https://api-muzea.su/api/news/image/abc.jpeg"
        XCTAssertEqual(ImageURL.makeup(url)?.absoluteString, url)
    }

    func testAbsoluteHTTPSURLIsReturnedUnchanged() {
        let url = "https://cdn.example.com/pic.png"
        XCTAssertEqual(ImageURL.makeup(url)?.absoluteString, url)
    }

    func testAbsoluteImageURLIsNotPrefixed() {
        let serverURL = "https://api-muzea.su/api/news/image/4b1d5b51.jpeg"
        XCTAssertEqual(ImageURL.makeup(serverURL)?.absoluteString, serverURL)
    }

    func testRelativePathWithLeadingSlashIsJoinedToBase() {
        XCTAssertEqual(
            ImageURL.makeup("/api/videos/stream/file.mp4")?.absoluteString,
            "https://api-muzea.su/api/videos/stream/file.mp4"
        )
    }

    func testRelativePathWithoutLeadingSlashIsJoinedToBase() {
        XCTAssertEqual(
            ImageURL.chat("api/avatars/uuid.png")?.absoluteString,
            "https://chat-muzea.su/api/avatars/uuid.png"
        )
    }

    func testBaseURLTrailingSlashDoesNotDouble() {
        XCTAssertEqual(
            ImageURL.chat("/api/avatars/uuid.png")?.absoluteString,
            "https://chat-muzea.su/api/avatars/uuid.png"
        )
    }

    func testSurroundingWhitespaceIsTrimmed() {
        XCTAssertEqual(
            ImageURL.makeup("  /a.png  ")?.absoluteString,
            "https://api-muzea.su/a.png"
        )
    }

    func testBlankOrNilPathReturnsNil() {
        XCTAssertNil(ImageURL.makeup(nil))
        XCTAssertNil(ImageURL.makeup(""))
        XCTAssertNil(ImageURL.makeup("   "))
        XCTAssertNil(ImageURL.chat("  "))
    }
}
