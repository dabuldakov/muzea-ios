import XCTest
@testable import Muzea

/// Контрактные тесты новых текстовых эндпоинтов чата: пути, методы и тела.
final class MessageRepositoryTests: XCTestCase {

    private var store: TokenStore!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        store = TestSupport.makeStore()
        store.token = "access"
        store.chatUserUuid = "me"
    }

    override func tearDown() {
        MockURLProtocol.reset()
        store = nil
        super.tearDown()
    }

    private func authorization() -> ChatAuthorization {
        let client = TestSupport.chatClient(tokenStore: store)
        return ChatAuthorization(
            client: client,
            auth: ChatAuthManager(client: client, store: store)
        )
    }

    private func stub(_ handler: @escaping (URLRequest) -> (Int, String)) {
        MockURLProtocol.handler = { request in
            let (status, body) = handler(request)
            return (MockURLProtocol.response(for: request, status: status), TestSupport.data(body))
        }
    }

    private func request(_ pathSuffix: String, method: String) -> URLRequest? {
        MockURLProtocol.requests.first {
            $0.url?.path.hasSuffix(pathSuffix) == true && $0.httpMethod == method
        }
    }

    func testEditMessageUsesPutAndTextBody() async throws {
        stub { _ in (200, #"{"messageUuid":"m1","messageId":5,"text":"new","isEdited":true}"#) }

        let result = try await MessageActionsRepositoryImpl(auth: authorization())
            .editMessage(messageUuid: "m1", text: "new")

        XCTAssertEqual(result.text, "new")
        let req = request("/api/messages/m1", method: "PUT")
        let body = req?.capturedBody
        let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        XCTAssertEqual(json?["text"] as? String, "new")
    }

    func testDeleteMessageUsesDelete() async throws {
        stub { _ in (204, "") }

        try await MessageActionsRepositoryImpl(auth: authorization())
            .deleteMessage(messageUuid: "m1")

        XCTAssertNotNil(request("/api/messages/m1", method: "DELETE"))
    }

    func testPinUsesGetAndUnpinUsesDelete() async throws {
        stub { _ in (204, "") }
        let repository = MessageActionsRepositoryImpl(auth: authorization())

        try await repository.pinMessage(chatUuid: "c1", messageUuid: "m1")
        try await repository.unpinMessage(chatUuid: "c1", messageUuid: "m1")

        XCTAssertNotNil(request("/api/messages/c1/pin/m1", method: "GET"))
        XCTAssertNotNil(request("/api/messages/c1/pin/m1", method: "DELETE"))
    }

    func testForwardPostsSourceAndTargetChat() async throws {
        stub { _ in (200, #"{"messageUuid":"copy-1"}"#) }

        _ = try await MessageActionsRepositoryImpl(auth: authorization())
            .forwardMessage(messageUuid: "m1", toChatUuid: "c2")

        let req = request("/api/messages/forward", method: "POST")
        let json = req?.capturedBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        }
        XCTAssertEqual(json?["messageUuid"] as? String, "m1")
        XCTAssertEqual(json?["targetChatUuid"] as? String, "c2")
    }

    func testToggleReactionPostsEmoji() async throws {
        stub { _ in (200, #"[{"emoji":"👍","count":1,"mine":true,"users":[]}]"#) }

        let reactions = try await MessageReactionRepositoryImpl(auth: authorization())
            .toggleReaction(messageUuid: "m1", emoji: "👍")

        XCTAssertEqual(reactions.first?.emoji, "👍")
        let req = request("/api/messages/m1/reactions", method: "POST")
        let json = req?.capturedBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        }
        XCTAssertEqual(json?["emoji"] as? String, "👍")
    }

    func testReceiptsDecodeWatermarks() async throws {
        stub { _ in
            (200, #"[{"userUuid":"u1","username":"bob","lastDeliveredMessageId":4,"lastReadMessageId":5}]"#)
        }

        let receipts = try await MessageReceiptRepositoryImpl(auth: authorization())
            .loadReceipts(chatUuid: "c1")

        XCTAssertEqual(receipts.first?.lastReadMessageId, 5)
        XCTAssertNotNil(request("/api/chats/c1/receipts", method: "GET"))
    }

    func testMessageStatusesUsePerMessageEndpoint() async throws {
        stub { _ in
            (200, #"[{"userId":7,"userUuid":"u1","status":"READ","deliveredAt":"2026-01-01T00:00:05","readAt":"2026-01-01T00:00:06"}]"#)
        }

        let statuses = try await MessageStatusRepositoryImpl(auth: authorization())
            .loadMessageStatuses(chatUuid: "c1", messageUuid: "m1")

        XCTAssertEqual(statuses.first?.userUuid, "u1")
        XCTAssertEqual(statuses.first?.readAt, "2026-01-01T00:00:06")
        XCTAssertNotNil(request("/api/messages/c1/status/m1", method: "GET"))
    }

    func testReportPostsMessageReason() async throws {
        stub { _ in (201, "{}") }

        try await ModerationRepositoryImpl(auth: authorization())
            .report(messageUuid: "m1", reason: "SPAM", comment: nil)

        let req = request("/api/reports", method: "POST")
        let json = req?.capturedBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        }
        XCTAssertEqual(json?["contentType"] as? String, "MESSAGE")
        XCTAssertEqual(json?["contentUuid"] as? String, "m1")
        XCTAssertEqual(json?["reason"] as? String, "SPAM")
    }

    func testBlockPostsUserUuid() async throws {
        stub { _ in (200, "{}") }

        try await ModerationRepositoryImpl(auth: authorization())
            .block(userUuid: "u2", reason: nil)

        let req = request("/api/blocked", method: "POST")
        let json = req?.capturedBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        }
        XCTAssertEqual(json?["blockUserUuid"] as? String, "u2")
    }

    func testIncrementalLoadsUseTimestampPath() async throws {
        stub { _ in (200, "[]") }
        let repository = MessageRepositoryImpl(
            auth: authorization(),
            cache: ChatMessagesCache()
        )

        _ = try await repository.loadMessagesAfter(
            chatUuid: "c1",
            timestamp: "2026-01-01T00:00:01"
        )
        _ = try await repository.loadMessagesUpdated(
            chatUuid: "c1",
            timestamp: "2026-01-01T00:00:02"
        )

        XCTAssertNotNil(request("/api/messages/c1/after/2026-01-01T00:00:01", method: "GET"))
        XCTAssertNotNil(request("/api/messages/c1/updated/2026-01-01T00:00:02", method: "GET"))
    }

    func testSendCarriesReplyAndClientMessageId() async throws {
        stub { _ in (200, #"{"messageUuid":"s1","messageId":7}"#) }
        let repository = MessageRepositoryImpl(
            auth: authorization(),
            cache: ChatMessagesCache()
        )

        _ = try await repository.sendMessage(
            chatUuid: "c1",
            text: "hi",
            replyToMessageUuid: "m1",
            clientMessageId: "client-1",
            power: 42
        )

        let req = request("/api/messages/c1", method: "POST")
        let json = req?.capturedBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        }
        XCTAssertEqual(json?["replyToMessageUuid"] as? String, "m1")
        XCTAssertEqual(json?["clientMessageId"] as? String, "client-1")
        XCTAssertEqual(json?["messageType"] as? String, "TEXT")
        XCTAssertEqual(json?["power"] as? Int, 42)
    }
}
