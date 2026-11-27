import XCTest
@testable import Muzea

final class NewsCommentAvatarTests: XCTestCase {

    func testCommentDTOCarriesAuthorAvatar() {
        let dto = NewsCommentDTO(
            id: 1,
            newsId: 2,
            content: "Hi",
            author: "bob",
            authorAvatarUrl: "/api/avatars/bob/1.png",
            createdAt: "2026-01-01T00:00:00"
        )

        XCTAssertEqual(dto.toDomain().authorAvatarUrl, "/api/avatars/bob/1.png")
    }

    func testCommentWithoutAvatarHasNil() {
        let dto = NewsCommentDTO(
            id: 1,
            newsId: 2,
            content: "Hi",
            author: "bob",
            authorAvatarUrl: nil,
            createdAt: "2026-01-01T00:00:00"
        )

        XCTAssertNil(dto.toDomain().authorAvatarUrl)
    }
}
