import XCTest
@testable import Muzea

/// Проверяет, что Codable-модели разбирают реальные ответы серверов.
final class ModelsDecodingTests: XCTestCase {

    func testDecodesNewsWithRelatedVideo() throws {
        let json = """
        {
          "id": 54,
          "title": "Новая тол",
          "content": "ыыы",
          "imageUrl": "http://90.188.89.63:8085/api/news/image/3911eb61.jpeg",
          "publishedAt": "2026-09-20T11:09:12Z",
          "author": "dabuldakov",
          "relatedVideo": {
            "id": 18,
            "title": "Tomsk river",
            "description": null,
            "url": "/api/videos/stream/0c0ec89e.mp4",
            "thumbnailUrl": "http://90.188.89.63:8085/api/videos/thumbnail/0c0ec89e.jpeg",
            "fileSize": 9478047,
            "duration": null,
            "views": 19,
            "likes": null,
            "uploadedBy": "dabuldakov",
            "uploadedAt": "2026-05-03T12:05:36.065212"
          }
        }
        """
        let news = try TestSupport.decode(NewsResponse.self, json)

        XCTAssertEqual(news.id, 54)
        XCTAssertEqual(news.author, "dabuldakov")
        XCTAssertEqual(news.relatedVideo?.id, 18)
        XCTAssertEqual(news.relatedVideo?.fileSize, 9478047)
        XCTAssertEqual(
            news.relatedVideo?.fullVideoURL?.absoluteString,
            "http://90.188.89.63:8085/api/videos/stream/0c0ec89e.mp4"
        )
        XCTAssertEqual(
            news.relatedVideo?.fullThumbnailURL?.absoluteString,
            "http://90.188.89.63:8085/api/videos/thumbnail/0c0ec89e.jpeg"
        )
    }

    func testDecodesNewsWithoutRelatedVideo() throws {
        let json = """
        {"id": 1, "title": "T", "content": "C", "imageUrl": null,
         "publishedAt": "2026-09-22T06:48:24Z", "author": "a", "relatedVideo": null}
        """
        let news = try TestSupport.decode(NewsResponse.self, json)
        XCTAssertNil(news.imageUrl)
        XCTAssertNil(news.relatedVideo)
    }

    func testDecodesVideoWithAbsoluteURL() throws {
        let json = """
        {"id": 1, "title": "V", "description": "d",
         "url": "https://cdn.example.com/v.mp4", "thumbnailUrl": null,
         "fileSize": 10, "duration": "00:10", "views": 5, "likes": 2,
         "uploadedBy": "me", "uploadedAt": "2026-01-01T00:00:00"}
        """
        let video = try TestSupport.decode(VideoResponse.self, json)
        XCTAssertEqual(video.fullVideoURL?.absoluteString, "https://cdn.example.com/v.mp4")
        XCTAssertNil(video.fullThumbnailURL)
    }

    func testDecodesChatAuthResponse() throws {
        let json = """
        {"token":"jwt","refreshToken":"r","userUuid":"u-1",
         "username":"alice","email":"a@b.c","avatarUrl":"/api/avatars/x.png"}
        """
        let auth = try TestSupport.decode(ChatAuthResponse.self, json)
        XCTAssertEqual(auth.token, "jwt")
        XCTAssertEqual(auth.userUuid, "u-1")
    }

    func testDecodesAuthResponseWithoutRole() throws {
        let json = #"{"token":"t","username":"alice"}"#
        let auth = try TestSupport.decode(AuthResponse.self, json)
        XCTAssertEqual(auth.username, "alice")
        XCTAssertNil(auth.role)
    }

    func testDecodesChatResponse() throws {
        let json = """
        {"chatUuid":"c-1","chatType":"GROUP","title":"Team","avatarUrl":null,
         "createdAt":"2026-01-01T00:00:00","updatedAt":"2026-01-01T00:00:00",
         "participantCount":3,"unreadCount":2,
         "lastMessage":{"messageUuid":"m-1","text":"hi","senderId":1,
                        "senderName":"Bob","createdAt":"2026-01-01T00:00:00"}}
        """
        let chat = try TestSupport.decode(ChatResponse.self, json)
        XCTAssertEqual(chat.id, "c-1")
        XCTAssertEqual(chat.lastMessage?.text, "hi")
        XCTAssertEqual(chat.unreadCount, 2)
    }

    func testDecodesContactResponse() throws {
        let json = """
        {"contactUuid":"k-1","contactUserId":1,"contactUserUuid":"u-2",
         "username":"bob","firstName":null,"lastName":null,"fullName":null,
         "avatarUrl":null,"contactName":null,"isOnline":true,
         "lastSeenAt":null,"addedAt":"2026-01-01T00:00:00"}
        """
        let contact = try TestSupport.decode(ContactResponse.self, json)
        XCTAssertEqual(contact.displayName, "bob")
        XCTAssertTrue(contact.isOnline)
    }

    func testDecodesMessageResponse() throws {
        let json = """
        {"messageUuid":"m-1","chatUuid":"c-1","senderId":1,"senderUuid":"u-1",
         "senderName":"Alice","senderAvatar":null,"text":"hello","messageType":"TEXT",
         "replyToMessageUuid":null,"isEdited":false,"isDeleted":false,"isPinned":false,
         "createdAt":"2026-01-01T00:00:00","updatedAt":null}
        """
        let message = try TestSupport.decode(MessageResponse.self, json)
        XCTAssertEqual(message.id, "m-1")
        XCTAssertEqual(message.text, "hello")
        XCTAssertEqual(message.isEdited, false)
    }

    func testDecodesChatParticipant() throws {
        let json = """
        {"userUuid":"u-1","userId":1,"username":"alice","firstName":null,
         "lastName":null,"fullName":"Alice A","nickname":null,"avatarUrl":null,
         "role":"OWNER","online":true,"lastSeenAt":null,"joinedAt":"2026-01-01T00:00:00"}
        """
        let participant = try TestSupport.decode(ChatParticipantResponse.self, json)
        XCTAssertEqual(participant.displayName, "Alice A")
        XCTAssertEqual(participant.role, "OWNER")
        XCTAssertEqual(participant.online, true)
    }

    func testDecodesPageResponse() throws {
        let json = """
        {"content":[{"messageUuid":"m-1"}],
         "empty":false,"first":true,"last":false,"number":0,
         "numberOfElements":1,"size":50,"totalElements":1,"totalPages":1}
        """
        let page = try TestSupport.decode(PageResponse<MessageResponse>.self, json)
        XCTAssertEqual(page.content.count, 1)
        XCTAssertEqual(page.totalElements, 1)
    }

    func testDecodesUserResponse() throws {
        let json = """
        {"id":7,"userName":"alice","email":"a@b.c","fullName":"Alice",
         "avatarUrl":null,"role":"USER","createdAt":null,"enabled":true}
        """
        let user = try TestSupport.decode(UserResponse.self, json)
        XCTAssertEqual(user.id, 7)
        XCTAssertEqual(user.userName, "alice")
    }
}