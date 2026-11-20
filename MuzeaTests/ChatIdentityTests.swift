import XCTest
@testable import Muzea

/// Идентичность chat-пользователя: сравнение `senderUuid` с UUID, который
/// вернул chat-сервер (а не с `sub` токена IdP).
final class ChatIdentityTests: XCTestCase {

    func testMessageIsSentByMatchingChatUser() {
        let message = TestData.message("m1", sender: "chat-uuid")
        XCTAssertTrue(message.isSent(by: "chat-uuid"))
        XCTAssertFalse(message.isSent(by: "auth-sub"))
    }

    func testMessageWithoutSenderOrIdentityIsNotMine() {
        XCTAssertFalse(TestData.message("m1", sender: nil).isSent(by: "chat-uuid"))
        XCTAssertFalse(TestData.message("m1", sender: "").isSent(by: "chat-uuid"))
        XCTAssertFalse(TestData.message("m1", sender: "chat-uuid").isSent(by: nil))
        XCTAssertFalse(TestData.message("m1", sender: "chat-uuid").isSent(by: ""))
    }

    func testActionsBuilderUsesChatUuidForOwnership() {
        let message = TestData.message("m1", text: "hi", sender: "chat-uuid")
            .replacing(messageId: 10)

        let mine = MessageActionsBuilder.build(
            message: message,
            myUserUuid: "chat-uuid",
            isGroupChat: true
        )
        XCTAssertTrue(mine.actions.contains(.edit))

        let foreign = MessageActionsBuilder.build(
            message: message,
            myUserUuid: "auth-sub",
            isGroupChat: true
        )
        XCTAssertFalse(foreign.actions.contains(.edit))
    }

    func testDeliveryStatusUsesChatUuidForOwnership() {
        let message = TestData.message("m1", sender: "chat-uuid")
            .replacing(messageId: 10)
        let receipts = [
            ChatReceipt(
                userUuid: "other",
                username: "other",
                fullName: nil,
                avatarUrl: nil,
                joinedAt: "2025-12-01T00:00:00",
                lastDeliveredMessageId: 10,
                lastDeliveredAt: "2026-01-01T00:00:01",
                lastReadMessageId: 10,
                lastReadAt: "2026-01-01T00:00:02"
            )
        ]

        XCTAssertEqual(
            MessageStatusCalculator.statusOf(
                message: message,
                receipts: receipts,
                myUserUuid: "chat-uuid"
            ),
            .read
        )
        XCTAssertNil(
            MessageStatusCalculator.statusOf(
                message: message,
                receipts: receipts,
                myUserUuid: "auth-sub"
            )
        )
    }
}

@MainActor
final class ChatIdentityViewModelTests: XCTestCase {

    func testLateIdentityIsAdopted() {
        let viewModel = ChatConversationViewModel(
            chatUuid: "c-1",
            myUserUuid: nil,
            isGroupChat: true,
            services: .fake()
        )

        viewModel.updateIdentity("chat-uuid")

        XCTAssertEqual(viewModel.myUserUuid, "chat-uuid")
    }

    func testEmptyOrRepeatedIdentityDoesNotResetState() {
        let viewModel = ChatConversationViewModel(
            chatUuid: "c-1",
            myUserUuid: "chat-uuid",
            isGroupChat: true,
            services: .fake()
        )

        viewModel.updateIdentity(nil)
        viewModel.updateIdentity("")
        viewModel.updateIdentity("chat-uuid")

        XCTAssertEqual(viewModel.myUserUuid, "chat-uuid")
    }
}
