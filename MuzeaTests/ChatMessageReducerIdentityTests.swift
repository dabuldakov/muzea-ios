import XCTest
@testable import Muzea

/// Дополнительные сценарии редьюсера: перенос локальных uuid в кэш, reply на
/// локальное сообщение и сохранение заряда при серверном эхе.
final class ChatMessageReducerIdentityTests: XCTestCase {

    func testToServerIdentitiesRewritesReplyTarget() {
        let reducer = ChatMessageReducer()
        _ = reducer.applyServerEcho(
            current: [TestData.message("local-1", createdAt: nil)],
            localUuid: "local-1",
            serverMessage: TestData.message("server-1", createdAt: "2026-01-01T00:00:01")
        )

        let reply = TestData.message("local-2", createdAt: nil)
            .replacing(replyToMessageUuid: "local-1")

        let cached = reducer.toServerIdentities([reply])

        XCTAssertEqual(cached.count, 1)
        XCTAssertEqual(cached[0].messageUuid, "local-2")
        XCTAssertEqual(cached[0].replyToMessageUuid, "server-1")
    }

    func testServerEchoMapsReplyFromServerToLocalUuid() {
        let reducer = ChatMessageReducer()
        _ = reducer.applyServerEcho(
            current: [TestData.message("local-1", createdAt: nil)],
            localUuid: "local-1",
            serverMessage: TestData.message("server-1", createdAt: "2026-01-01T00:00:01")
        )

        let localReply = TestData.message("local-2", createdAt: nil)
            .replacing(replyToMessageUuid: "local-1")
        let serverReply = TestData.message("server-2", createdAt: "2026-01-01T00:00:02")
            .replacing(replyToMessageUuid: "server-1")

        let result = reducer.applyServerEcho(
            current: [localReply],
            localUuid: "local-2",
            serverMessage: serverReply
        )

        XCTAssertEqual(result[0].messageUuid, "local-2")
        XCTAssertEqual(result[0].replyToMessageUuid, "local-1")
    }

    func testServerEchoKeepsLocalPowerWhenServerSendsZero() {
        let reducer = ChatMessageReducer()
        let local = TestData.message("local-1", createdAt: nil).replacing(power: 77)

        let result = reducer.applyServerEcho(
            current: [local],
            localUuid: "local-1",
            serverMessage: TestData.message("server-1", createdAt: "2026-01-01T00:00:01")
                .replacing(power: 0)
        )

        XCTAssertEqual(result[0].power, 77)
    }

    func testServerEchoUsesServerPowerWhenPresent() {
        let reducer = ChatMessageReducer()
        let local = TestData.message("local-1", createdAt: nil).replacing(power: 55)

        let result = reducer.applyServerEcho(
            current: [local],
            localUuid: "local-1",
            serverMessage: TestData.message("server-1", createdAt: "2026-01-01T00:00:01")
                .replacing(power: 90)
        )

        XCTAssertEqual(result[0].power, 90)
    }

    func testUpdateMessageKeepsOrderAndIgnoresUnknownUuid() {
        let reducer = ChatMessageReducer()
        let first = TestData.message("m1", text: "one", createdAt: "2026-01-01T00:00:01")
        let second = TestData.message("m2", text: "two", createdAt: "2026-01-01T00:00:02")

        let updated = reducer.updateMessage(
            current: [first, second],
            updated: second.replacing(text: "two edited")
        )
        XCTAssertEqual(updated.map(\.messageUuid), ["m1", "m2"])
        XCTAssertEqual(updated[1].text, "two edited")

        let unknown = TestData.message("m3", createdAt: "2026-01-01T00:00:03")
        XCTAssertEqual(
            reducer.updateMessage(current: [first], updated: unknown).map(\.text),
            [first.text]
        )
    }

    func testUndatedMessageSortsAfterDatedInBothDirections() {
        let dated = TestData.message("dated", createdAt: "2026-01-01T00:00:01")
        let undated = TestData.message("undated", createdAt: nil)

        XCTAssertTrue(ChatMessageReducer.areInIncreasingOrder(dated, undated))
        XCTAssertFalse(ChatMessageReducer.areInIncreasingOrder(undated, dated))
        XCTAssertFalse(ChatMessageReducer.areInIncreasingOrder(undated, undated))
    }

    func testRemoveMessageFiltersByUuid() {
        let reducer = ChatMessageReducer()
        let list = [
            TestData.message("m1", createdAt: "2026-01-01T00:00:01"),
            TestData.message("m2", createdAt: "2026-01-01T00:00:02")
        ]

        XCTAssertEqual(
            reducer.removeMessage(current: list, messageUuid: "m1").map(\.messageUuid),
            ["m2"]
        )
        XCTAssertEqual(
            reducer.removeMessage(current: list, messageUuid: "missing").count,
            2
        )
    }
}
