import XCTest
@testable import Muzea

final class MessagePopupRowsTests: XCTestCase {

    private let myUuid = "me"

    func testBuildsReadersWithStatusesTimesAndReactions() {
        let message = makeMessage(
            sender: myUuid,
            reactions: [
                MessageReaction(
                    emoji: "👍",
                    count: 1,
                    mine: false,
                    users: [ReactionUser(userUuid: "anna", at: "2026-01-01T10:01:00")]
                ),
                MessageReaction(
                    emoji: "❤️",
                    count: 2,
                    mine: false,
                    users: [
                        ReactionUser(userUuid: "anna", at: "2026-01-01T10:02:00"),
                        ReactionUser(userUuid: "sveta", at: "2026-01-01T11:01:00")
                    ]
                ),
                MessageReaction(
                    emoji: "😂",
                    count: 1,
                    mine: false,
                    users: [ReactionUser(userUuid: "guest", at: "2026-01-01T11:30:00")]
                )
            ]
        )

        let rows = MessagePopupRows.build(
            message: message,
            receipts: [
                receipt(uuid: "anna", name: "Аня", readAt: "2026-01-01T10:00:00"),
                receipt(uuid: "boris", name: "Борис", deliveredAt: "2026-01-01T09:00:00"),
                receipt(uuid: "sveta", name: "Света", readAt: nil, deliveredAt: nil)
            ],
            statuses: [
                MessageStatus(
                    userId: nil,
                    userUuid: "anna",
                    status: "READ",
                    deliveredAt: "2026-01-01T09:59:00",
                    readAt: "2026-01-01T10:00:00"
                )
            ],
            myUserUuid: myUuid,
            youLabel: "Вы",
            unknownLabel: "Неизвестный",
            formatTime: { $0 ?? "" }
        )

        XCTAssertEqual(rows.map(\.id), ["anna", "boris", "sveta", "guest"])
        XCTAssertEqual(rows[0].name, "Аня")
        XCTAssertEqual(rows[0].status, .read)
        XCTAssertEqual(rows[0].time, "2026-01-01T10:00:00")
        // Реакции автора идут в порядке времени, а не порядка прихода.
        XCTAssertEqual(rows[0].emojis, ["👍", "❤️"])

        XCTAssertEqual(rows[1].name, "Борис")
        XCTAssertEqual(rows[1].status, .delivered)
        XCTAssertEqual(rows[1].time, "2026-01-01T09:00:00")
        XCTAssertTrue(rows[1].emojis.isEmpty)

        // Света ещё не прочитала: статус «отправлено», времени по сообщению
        // нет, но её реакция видна.
        XCTAssertEqual(rows[2].status, .sent)
        XCTAssertEqual(rows[2].time, "")
        XCTAssertEqual(rows[2].emojis, ["❤️"])

        // Автор реакции без квитанции — отдельной строкой без статуса.
        XCTAssertNil(rows[3].status)
        XCTAssertEqual(rows[3].name, "Неизвестный")
        XCTAssertEqual(rows[3].emojis, ["😂"])
        XCTAssertEqual(rows[3].time, "2026-01-01T11:30:00")
    }

    func testForeignMessageShowsReactionAuthorsOnly() {
        let message = makeMessage(
            sender: "someone",
            reactions: [
                MessageReaction(
                    emoji: "🔥",
                    count: 2,
                    mine: true,
                    users: [
                        ReactionUser(userUuid: myUuid, at: "2026-01-01T12:00:00"),
                        ReactionUser(userUuid: "stranger", at: "2026-01-01T12:05:00")
                    ]
                )
            ]
        )

        let rows = MessagePopupRows.build(
            message: message,
            receipts: [
                receipt(uuid: myUuid, name: "Я", readAt: nil),
                receipt(uuid: "someone", name: "Автор", readAt: nil)
            ],
            statuses: [],
            myUserUuid: myUuid,
            youLabel: "Вы",
            unknownLabel: "Неизвестный",
            formatTime: { $0 ?? "" }
        )

        XCTAssertEqual(rows.map(\.id), [myUuid, "stranger"])
        XCTAssertEqual(rows[0].name, "Вы")
        XCTAssertEqual(rows[0].emojis, ["🔥"])
        XCTAssertNil(rows[0].status)
        XCTAssertEqual(rows[1].name, "Неизвестный")
        XCTAssertNil(rows[1].status)
    }

    func testVisibleEmojisCollapsesOverflow() {
        let exact = MessagePopupRows.visibleEmojis(["👍", "❤️", "🔥"])
        XCTAssertEqual(exact.shown, ["👍", "❤️", "🔥"])
        XCTAssertEqual(exact.hidden, 0)

        let overflow = MessagePopupRows.visibleEmojis(["👍", "❤️", "🔥", "😂", "🎉"])
        XCTAssertEqual(overflow.shown, ["👍", "❤️", "🔥"])
        XCTAssertEqual(overflow.hidden, 2)
    }

    // MARK: - Helpers

    private func makeMessage(
        sender: String,
        reactions: [MessageReaction] = []
    ) -> ChatMessage {
        ChatMessage(
            messageUuid: "m-1",
            messageId: 10,
            chatUuid: "c-1",
            senderId: nil,
            senderUuid: sender,
            senderName: nil,
            senderAvatar: nil,
            text: "привет",
            messageType: "TEXT",
            replyToMessageUuid: nil,
            isEdited: false,
            isDeleted: false,
            isPinned: false,
            createdAt: "2026-01-01T00:00:00",
            updatedAt: nil,
            reactions: reactions
        )
    }

    private func receipt(
        uuid: String,
        name: String,
        deliveredAt: String? = nil,
        readAt: String?
    ) -> ChatReceipt {
        ChatReceipt(
            userUuid: uuid,
            username: uuid,
            fullName: name,
            avatarUrl: nil,
            joinedAt: "2025-12-01T00:00:00",
            lastDeliveredMessageId: deliveredAt != nil ? 10 : nil,
            lastDeliveredAt: deliveredAt,
            lastReadMessageId: readAt != nil ? 10 : nil,
            lastReadAt: readAt
        )
    }
}
