import XCTest
@testable import Muzea

final class PushPayloadTests: XCTestCase {

    func testMessageRouteUsesServerKeys() {
        let data: [AnyHashable: Any] = [
            "type": "MESSAGE",
            "chatUuid": "c1",
            "messageUuid": "m1",
            "senderName": "Alice",
            "chatTitle": "Team",
            "chatAvatar": "/avatar.png",
            "messageText": "hi"
        ]

        let route = PushPayload.route(from: data)

        XCTAssertEqual(route, .chat(ChatPushTarget(
            chatUuid: "c1",
            title: "Team",
            avatarUrl: "/avatar.png",
            messageUuid: "m1"
        )))
        XCTAssertEqual(PushPayload.title(for: data), nil)
        XCTAssertEqual(PushPayload.body(for: data), "hi")
    }

    func testMessageFallbackKeysAndTitleFromSender() {
        let data: [AnyHashable: Any] = [
            "type": "MESSAGE",
            "chat_uuid": "c2",
            "sender_name": "Bob"
        ]

        let route = PushPayload.route(from: data)
        XCTAssertEqual(route, .chat(ChatPushTarget(
            chatUuid: "c2",
            title: "Bob",
            avatarUrl: nil,
            messageUuid: nil
        )))
    }

    func testNewsRouteAndUnknownTypes() {
        XCTAssertEqual(
            PushPayload.route(from: ["type": "NEWS", "newsId": "42"]),
            .news(id: 42)
        )
        XCTAssertNil(PushPayload.route(from: ["type": "NEWS", "newsId": "bad"]))
        XCTAssertNil(PushPayload.route(from: ["type": "TYPING", "chatUuid": "c1"]))
    }

    func testMissingChatUuidIsIgnored() {
        XCTAssertNil(PushPayload.route(from: ["type": "MESSAGE"]))
    }
}

@MainActor
final class AppRouterTests: XCTestCase {

    func testChatRouteSelectsChatsTabAndCreatesTarget() {
        let router = AppRouter()

        router.handle(.chat(ChatPushTarget(
            chatUuid: "c1",
            title: "Alice",
            avatarUrl: "/a.png",
            messageUuid: "m1"
        )))

        XCTAssertEqual(router.selectedTab, AppRouter.tabChats)
        XCTAssertEqual(router.chatTarget?.chatUuid, "c1")
        XCTAssertEqual(router.chatTarget?.title, "Alice")
        XCTAssertNil(router.consumeChatTarget())
    }

    func testNewsRouteSelectsNewsTab() {
        let router = AppRouter()

        router.handle(.news(id: 7))

        XCTAssertEqual(router.selectedTab, AppRouter.tabNews)
        XCTAssertEqual(router.newsTarget, 7)
        XCTAssertNil(router.consumeNewsTarget())
    }
}

final class ActiveChatTrackerTests: XCTestCase {

    func testTracksOnlyCurrentChat() {
        let tracker = ActiveChatTracker()
        tracker.enter("c1")
        XCTAssertEqual(tracker.chatUuid, "c1")

        tracker.leave("other")
        XCTAssertEqual(tracker.chatUuid, "c1")

        tracker.leave("c1")
        XCTAssertNil(tracker.chatUuid)
    }
}
