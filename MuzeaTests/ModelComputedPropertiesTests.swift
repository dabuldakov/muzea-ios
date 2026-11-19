import XCTest
@testable import Muzea

/// Вычисляемые поля моделей: имена, идентификаторы и значения по умолчанию.
/// Это дешёвые тесты, но именно они ловят регрессии при добавлении полей.
final class ModelComputedPropertiesTests: XCTestCase {

    // MARK: - Contact

    func testContactDisplayNamePriority() {
        XCTAssertEqual(
            makeContact(contactName: "Ник", fullName: "Полное", username: "user").displayName,
            "Ник"
        )
        XCTAssertEqual(
            makeContact(contactName: nil, fullName: "Полное", username: "user").displayName,
            "Полное"
        )
        XCTAssertEqual(
            makeContact(contactName: nil, fullName: nil, username: "user").displayName,
            "user"
        )
        XCTAssertEqual(
            makeContact(contactName: nil, fullName: nil, username: nil).displayName,
            L10n.contactFallbackName
        )
    }

    func testContactIdAndPresenceFallback() {
        let contact = makeContact(lastSeenAt: "2026-01-01T10:00:00")
        XCTAssertEqual(contact.id, "k-u-1")

        let updated = contact.replacingPresence(online: true, lastSeenAt: nil)
        XCTAssertTrue(updated.isOnline)
        XCTAssertEqual(updated.lastSeenAt, "2026-01-01T10:00:00")

        let moved = contact.replacingPresence(online: false, lastSeenAt: "2026-01-02T10:00:00")
        XCTAssertFalse(moved.isOnline)
        XCTAssertEqual(moved.lastSeenAt, "2026-01-02T10:00:00")
    }

    // MARK: - ChatAttachment

    func testChatAttachmentIdUsesFirstAvailableField() {
        XCTAssertEqual(makeAttachment(uuid: "a-1").id, "a-1")
        XCTAssertEqual(makeAttachment(uuid: nil, fileUrl: "/files/a.jpg").id, "/files/a.jpg")
        XCTAssertEqual(
            makeAttachment(uuid: nil, fileUrl: nil, fileName: "a.jpg").id,
            "a.jpg"
        )
        XCTAssertEqual(makeAttachment(uuid: nil, fileUrl: nil, fileName: nil).id, "attachment")
    }

    // MARK: - ChatReceipt / ChatParticipant

    func testChatReceiptDisplayNamePriority() {
        XCTAssertEqual(makeReceipt(fullName: "Аня", username: "anna").displayName, "Аня")
        XCTAssertEqual(makeReceipt(fullName: nil, username: "anna").displayName, "anna")
        XCTAssertEqual(makeReceipt(fullName: nil, username: nil).displayName, L10n.participant)
    }

    func testChatParticipantIdAndDisplayName() {
        XCTAssertEqual(makeParticipant(uuid: "u-1").id, "u-1")
        XCTAssertEqual(
            makeParticipant(uuid: nil, userId: 7, username: "bob").id,
            "7-bob"
        )

        XCTAssertEqual(
            makeParticipant(uuid: "u-1", username: "bob", fullName: "Борис").displayName,
            "Борис"
        )
        XCTAssertEqual(
            makeParticipant(uuid: "u-1", username: "bob", fullName: nil).displayName,
            "bob"
        )
        XCTAssertEqual(
            makeParticipant(uuid: "u-1", username: nil, fullName: nil).displayName,
            L10n.participant
        )
    }

    // MARK: - Requests / DTO

    func testSendMessageRequestOptionalFieldsDefaultToNil() {
        let request = SendMessageRequest(text: "hi", messageType: "TEXT")
        XCTAssertNil(request.replyToMessageUuid)
        XCTAssertNil(request.clientMessageId)
        XCTAssertNil(request.power)
        XCTAssertNil(request.attachments)
        XCTAssertNil(request.gif)
    }

    func testGifDTOKeepsKeyAndResolvesRelativeURLs() {
        let dto = GifDTO(
            gifUuid: "g-1",
            provider: "klipy",
            providerGifId: "p-1",
            title: nil,
            url: "/media/gif.mp4",
            previewUrl: "https://cdn.example.com/p.jpg",
            mp4Url: nil,
            width: 320,
            height: 240
        )

        let gif = dto.toDomain()

        XCTAssertEqual(gif.gifKey, "g-1")
        XCTAssertEqual(gif.provider, "klipy")
        XCTAssertEqual(gif.previewUrl, "https://cdn.example.com/p.jpg")
        XCTAssertTrue(gif.url.hasPrefix("http"))
        XCTAssertNil(gif.mp4Url)
        XCTAssertEqual(gif.width, 320)
        XCTAssertEqual(gif.height, 240)
    }

    // MARK: - Helpers

    private func makeContact(
        contactName: String? = nil,
        fullName: String? = nil,
        username: String? = nil,
        lastSeenAt: String? = nil
    ) -> Contact {
        Contact(
            contactUuid: "k-u-1",
            contactUserId: nil,
            contactUserUuid: "u-1",
            username: username,
            firstName: nil,
            lastName: nil,
            fullName: fullName,
            avatarUrl: nil,
            contactName: contactName,
            isOnline: false,
            lastSeenAt: lastSeenAt,
            addedAt: nil
        )
    }

    private func makeAttachment(
        uuid: String?,
        fileUrl: String? = nil,
        fileName: String? = nil
    ) -> ChatAttachment {
        ChatAttachment(
            attachmentUuid: uuid,
            fileName: fileName,
            fileUrl: fileUrl,
            thumbnailUrl: nil,
            mp4Url: nil,
            fileSize: nil,
            mimeType: nil,
            type: "IMAGE",
            width: nil,
            height: nil,
            duration: nil,
            gifKey: nil
        )
    }

    private func makeReceipt(fullName: String?, username: String?) -> ChatReceipt {
        ChatReceipt(
            userUuid: "u-1",
            username: username,
            fullName: fullName,
            avatarUrl: nil,
            joinedAt: nil,
            lastDeliveredMessageId: nil,
            lastDeliveredAt: nil,
            lastReadMessageId: nil,
            lastReadAt: nil
        )
    }

    private func makeParticipant(
        uuid: String?,
        userId: Int64? = nil,
        username: String? = nil,
        fullName: String? = nil
    ) -> ChatParticipant {
        ChatParticipant(
            userUuid: uuid,
            userId: userId,
            username: username,
            firstName: nil,
            lastName: nil,
            fullName: fullName,
            nickname: nil,
            avatarUrl: nil,
            role: "MEMBER",
            online: nil,
            lastSeenAt: nil,
            joinedAt: nil
        )
    }
}
