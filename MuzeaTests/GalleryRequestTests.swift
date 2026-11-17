import XCTest
@testable import Muzea

final class GalleryRequestTests: XCTestCase {

    func testRequestKeepsMessageAndClampsIndex() {
        let message = Self.message(
            attachments: [
                Self.attachment(uuid: "a", type: "IMAGE"),
                Self.attachment(uuid: "b", type: "IMAGE")
            ],
            senderDeleted: false
        )

        let request = GalleryRequest(message: message, tappedIndex: 99)

        XCTAssertEqual(request?.images.map(\.attachmentUuid), ["a", "b"])
        XCTAssertEqual(request?.startIndex, 1)
        XCTAssertEqual(request?.senderName, "Аня")
    }

    func testRequestReturnsNilWithoutImages() {
        let message = Self.message(
            attachments: [Self.attachment(uuid: "v", type: "VIDEO")],
            senderDeleted: false
        )

        XCTAssertNil(GalleryRequest(message: message, tappedIndex: 0))
        XCTAssertNil(GalleryRequest(message: Self.message(attachments: nil), tappedIndex: 0))
    }

    func testDeletedSenderShowsPlaceholderName() {
        let message = Self.message(
            attachments: [Self.attachment(uuid: "a", type: "IMAGE")],
            senderDeleted: true
        )

        XCTAssertEqual(
            GalleryRequest(message: message, tappedIndex: 0)?.senderName,
            L10n.deletedUser
        )
    }

    private static func message(
        attachments: [ChatAttachment]?,
        senderDeleted: Bool? = false
    ) -> ChatMessage {
        ChatMessage(
            messageUuid: "m-1",
            chatUuid: "c-1",
            senderId: nil,
            senderUuid: "u-1",
            senderName: "Аня",
            senderAvatar: nil,
            text: nil,
            messageType: "IMAGE",
            replyToMessageUuid: nil,
            isEdited: false,
            isDeleted: false,
            isPinned: false,
            createdAt: "2026-01-01T00:00:00",
            updatedAt: nil,
            attachments: attachments,
            senderDeleted: senderDeleted
        )
    }

    private static func attachment(uuid: String, type: String) -> ChatAttachment {
        ChatAttachment(
            attachmentUuid: uuid,
            fileName: "photo.jpg",
            fileUrl: nil,
            thumbnailUrl: nil,
            mp4Url: nil,
            fileSize: nil,
            mimeType: nil,
            type: type,
            width: nil,
            height: nil,
            duration: nil,
            gifKey: nil
        )
    }
}
