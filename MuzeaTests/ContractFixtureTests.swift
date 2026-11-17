import XCTest
@testable import Muzea

/// Контрактные тесты на общих фикстурах `docs/fixtures`. Те же JSON должны
/// использоваться Android-тестами, поэтому расхождение API ловится на обеих
/// платформах до релиза.
final class ContractFixtureTests: XCTestCase {

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

    func testChatsFixtureDecodesIntoDomainChats() throws {
        let dtos = try decode([ChatDTO].self, "chat/chats.json")
        let chats = dtos.map { $0.toDomain() }

        XCTAssertEqual(chats.count, 2)
        XCTAssertEqual(chats[0].chatUuid, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(chats[0].chatType, "PRIVATE")
        XCTAssertEqual(chats[0].lastMessage?.text, "hello")
        XCTAssertEqual(chats[0].unreadCount, 3)
        XCTAssertEqual(chats[1].chatType, "GROUP")
    }

    func testMessagesFixtureDecodesMediaReactionsAndReply() throws {
        let dtoPage = try decode(PageResponse<ChatMessageDTO>.self, "chat/messages_page.json")
        let messages = dtoPage.content.map { $0.toDomain() }

        XCTAssertEqual(messages.count, 2)
        let text = messages[0]
        XCTAssertEqual(text.messageId, 101)
        XCTAssertEqual(text.messageType, "TEXT")
        XCTAssertEqual(text.isPinned, true)
        XCTAssertEqual(text.reactions?.first?.emoji, "👍")
        XCTAssertEqual(text.reactions?.first?.users?.first?.userUuid, "u-bob")

        let media = messages[1]
        XCTAssertEqual(media.messageType, "IMAGE")
        XCTAssertEqual(media.replyToMessageUuid, text.messageUuid)
        XCTAssertEqual(media.power, 42)
        XCTAssertEqual(media.attachments?.first?.attachmentUuid, "cccccccc-cccc-cccc-cccc-cccccccccccc")
        XCTAssertEqual(media.attachments?.first?.type, "IMAGE")
    }

    func testReceiptsAndStatusesFixtures() throws {
        let receipts = try decode([ChatReceiptDTO].self, "chat/receipts.json").map { $0.toDomain() }
        let statuses = try decode([MessageStatusDTO].self, "chat/message_statuses.json").map { $0.toDomain() }

        XCTAssertEqual(receipts.count, 2)
        XCTAssertEqual(receipts[1].lastReadMessageId, 102)
        XCTAssertEqual(statuses.count, 2)
        XCTAssertEqual(statuses[0].status, "READ")
        XCTAssertEqual(statuses[0].userUuid, "u-alice")
        XCTAssertEqual(statuses[1].status, "DELIVERED")
    }

    func testAttachmentAndParticipantsFixtures() throws {
        let attachment = try decode(ChatAttachmentDTO.self, "chat/attachment.json").toDomain()
        let participants = try decode([ChatParticipantDTO].self, "chat/participants.json").map { $0.toDomain() }

        XCTAssertEqual(attachment.fileName, "cat.jpg")
        XCTAssertEqual(attachment.fileSize, 12345)
        XCTAssertEqual(participants.count, 2)
        XCTAssertEqual(participants[0].role, "OWNER")
        XCTAssertEqual(participants[1].username, "bob")
    }

    func testMediaTypeGoldenTableMatchesPolicy() throws {
        struct Golden: Decodable {
            let cases: [Case]

            struct Case: Decodable {
                let fileName: String
                let kind: String
                let messageType: String
                let maxBytes: Int64
            }
        }

        let golden = try decode(Golden.self, "chat/media_types.json")
        for item in golden.cases {
            let rule = AttachmentPolicy.rule(for: item.fileName)
            XCTAssertEqual(rule?.kind.rawValue, item.kind, item.fileName)
            XCTAssertEqual(rule?.maxBytes, item.maxBytes, item.fileName)
            if let kind = rule?.kind {
                XCTAssertEqual(
                    AttachmentPolicy.messageType(for: [kind]),
                    item.messageType,
                    item.fileName
                )
            }
        }
    }

    func testGifFixtureParsesLikeTheApp() throws {
        let gifs = KlipyGifRepository.parse(try fixture("chat/gif_search.json"))

        XCTAssertEqual(gifs.count, 1)
        XCTAssertEqual(gifs[0].providerGifId, "party-cat")
        XCTAssertEqual(gifs[0].url, "https://cdn/hd.webp")
        XCTAssertEqual(gifs[0].mp4Url, "https://cdn/hd.mp4")
    }
}
