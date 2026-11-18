import XCTest
@testable import Muzea

/// Краевые случаи DTO: сервер может не прислать новые/опциональные поля,
/// а старые клиенты обязаны декодировать ответ без падений.
final class DTOEdgeCaseTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    func testChatWithoutOptionalFields() throws {
        let chat = try decode(ChatDTO.self, #"{"chatUuid":"c-1"}"#).toDomain()

        XCTAssertEqual(chat.chatUuid, "c-1")
        XCTAssertNil(chat.chatType)
        XCTAssertNil(chat.title)
        XCTAssertNil(chat.lastMessage)
        XCTAssertNil(chat.peerDeleted)
        XCTAssertNil(chat.unreadCount)
    }

    func testMessageWithoutOptionalFields() throws {
        let message = try decode(ChatMessageDTO.self, #"{"messageUuid":"m-1"}"#).toDomain()

        XCTAssertEqual(message.messageUuid, "m-1")
        XCTAssertNil(message.messageId)
        XCTAssertNil(message.isEdited)
        XCTAssertNil(message.power)
        XCTAssertNil(message.attachments)
        XCTAssertNil(message.reactions)
        XCTAssertNil(message.senderDeleted)
    }

    func testAttachmentWithoutOptionalFields() throws {
        let attachment = try decode(ChatAttachmentDTO.self, #"{"fileName":"a.bin"}"#).toDomain()

        XCTAssertEqual(attachment.fileName, "a.bin")
        XCTAssertNil(attachment.attachmentUuid)
        XCTAssertNil(attachment.type)
        XCTAssertNil(attachment.gifKey)
        XCTAssertNil(attachment.duration)
    }

    func testMessageKeepsSenderDeletedAndPower() throws {
        let message = try decode(
            ChatMessageDTO.self,
            #"{"messageUuid":"m-1","power":77,"senderDeleted":true,"isPinned":true}"#
        ).toDomain()

        XCTAssertEqual(message.power, 77)
        XCTAssertEqual(message.senderDeleted, true)
        XCTAssertEqual(message.isPinned, true)
    }

    func testReceiptAndStatusWithoutOptionalFields() throws {
        let receipt = try decode(ChatReceiptDTO.self, #"{"userUuid":"u-1"}"#).toDomain()
        XCTAssertEqual(receipt.userUuid, "u-1")
        XCTAssertNil(receipt.lastReadMessageId)

        let status = try decode(MessageStatusDTO.self, #"{"status":"READ"}"#).toDomain()
        XCTAssertEqual(status.status, "READ")
    }

    func testVideoWithoutOptionalFields() throws {
        let video = try decode(
            VideoDTO.self,
            #"{"id":1,"title":"V","url":"/v.mp4","views":0,"uploadedBy":"me","uploadedAt":"2026-01-01T00:00:00"}"#
        ).toDomain()

        XCTAssertEqual(video.id, 1)
        XCTAssertNil(video.durationSeconds)
        XCTAssertNil(video.likes)
        XCTAssertEqual(video.views, 0)
    }

    func testNewsRequiresCoreFields() throws {
        let news = try decode(
            NewsDTO.self,
            #"{"id":1,"title":"T","content":"C","author":"me","publishedAt":"2026-01-01T00:00:00"}"#
        ).toDomain()

        XCTAssertNil(news.imageUrl)
        XCTAssertNil(news.relatedVideo)
    }

    func testPageResponseAllowsMissingMetadata() throws {
        let page = try decode(
            PageResponse<ChatMessageDTO>.self,
            #"{"content":[{"messageUuid":"m-1"}]}"#
        )

        XCTAssertEqual(page.content.count, 1)
        XCTAssertNil(page.totalElements)
        XCTAssertNil(page.number)
    }
}
