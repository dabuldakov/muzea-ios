import XCTest
@testable import Muzea

/// Текстовый чат: статусы прочтения, действия, упоминания, черновики и
/// ViewModel-сценарии ответов/правок/пересылки.
final class ChatTextParityTests: XCTestCase {

    private func receipt(
        _ userUuid: String,
        read: Int64?,
        delivered: Int64?,
        joinedAt: String? = "2026-01-01T00:00:00"
    ) -> ChatReceiptResponse {
        ChatReceiptResponse(
            userUuid: userUuid,
            username: userUuid,
            fullName: nil,
            avatarUrl: nil,
            joinedAt: joinedAt,
            lastDeliveredMessageId: delivered,
            lastDeliveredAt: delivered == nil ? nil : "2026-01-01T00:00:05",
            lastReadMessageId: read,
            lastReadAt: read == nil ? nil : "2026-01-01T00:00:06"
        )
    }

    private func message(
        _ uuid: String,
        id: Int64?,
        sender: String = "me",
        createdAt: String = "2026-01-01T00:00:02"
    ) -> MessageResponse {
        TestData.message(uuid, createdAt: createdAt, sender: sender)
            .replacing(messageId: id)
    }
}

// MARK: - Receipt statuses

extension ChatTextParityTests {

    func testStatusIsNilForForeignMessage() {
        let status = MessageStatusCalculator.statusOf(
            message: message("m1", id: 10, sender: "other"),
            receipts: [],
            myUserUuid: "me"
        )
        XCTAssertNil(status)
    }

    func testLocalMessageIsSendingOrFailed() {
        let local = TestData.message("local-1", sender: "me", createdAt: nil)
        XCTAssertEqual(
            MessageStatusCalculator.statusOf(message: local, receipts: [], myUserUuid: "me"),
            MessageDeliveryStatus.sending
        )
        XCTAssertEqual(
            MessageStatusCalculator.statusOf(
                message: local,
                receipts: [],
                myUserUuid: "me",
                failedMessages: ["local-1"]
            ),
            MessageDeliveryStatus.failed
        )
    }

    func testUnloadedReceiptsNeverClaimRead() {
        XCTAssertEqual(
            MessageStatusCalculator.statusOf(
                message: message("m1", id: 10),
                receipts: [receipt("u1", read: 999, delivered: 999)],
                myUserUuid: "me",
                receiptsLoaded: false
            ),
            MessageDeliveryStatus.sent
        )
    }

    func testReadWinsOverDelivered() {
        let receipts = [
            receipt("u1", read: 10, delivered: 10),
            receipt("u2", read: 12, delivered: 12)
        ]
        XCTAssertEqual(
            MessageStatusCalculator.statusOf(
                message: message("m1", id: 10),
                receipts: receipts,
                myUserUuid: "me"
            ),
            MessageDeliveryStatus.read
        )
    }

    func testDeliveredWhenNotEveryoneRead() {
        let receipts = [
            receipt("u1", read: 10, delivered: 10),
            receipt("u2", read: nil, delivered: 10)
        ]
        XCTAssertEqual(
            MessageStatusCalculator.statusOf(
                message: message("m1", id: 10),
                receipts: receipts,
                myUserUuid: "me"
            ),
            MessageDeliveryStatus.delivered
        )
    }

    func testSentWhenSomeHaveNotDelivered() {
        let receipts = [
            receipt("u1", read: 10, delivered: 10),
            receipt("u2", read: nil, delivered: 4)
        ]
        XCTAssertEqual(
            MessageStatusCalculator.statusOf(
                message: message("m1", id: 10),
                receipts: receipts,
                myUserUuid: "me"
            ),
            MessageDeliveryStatus.sent
        )
    }

    func testLateJoinerDoesNotHoldStatusBack() {
        let receipts = [
            receipt("u1", read: 10, delivered: 10),
            receipt("late", read: nil, delivered: nil, joinedAt: "2026-01-01T00:00:03")
        ]
        XCTAssertEqual(
            MessageStatusCalculator.statusOf(
                message: message("m1", id: 10),
                receipts: receipts,
                myUserUuid: "me"
            ),
            MessageDeliveryStatus.read
        )
    }

    func testParticipantStatusesSortedReadFirst() {
        let receipts = [
            receipt("u1", read: nil, delivered: nil),
            receipt("u2", read: 10, delivered: 10),
            receipt("u3", read: nil, delivered: 10)
        ]

        let rows = MessageStatusCalculator.participantStatuses(
            message: message("m1", id: 10),
            receipts: receipts,
            myUserUuid: "me"
        )

        XCTAssertEqual(rows.map(\.status), [.read, .delivered, .sent])
    }
}

// MARK: - Actions

extension ChatTextParityTests {

    func testOwnTextMessageOffersEditDeleteAndStatusInGroup() {
        let message = TestData.message("m1", text: "hi")
            .replacing(messageId: 5, isPinned: false)

        let result = MessageActionsBuilder.build(
            message: message,
            myUserUuid: "me",
            isGroupChat: true
        )

        XCTAssertTrue(result.actions.contains(.edit))
        XCTAssertTrue(result.actions.contains(.delete))
        XCTAssertTrue(result.actions.contains(.reply))
        XCTAssertTrue(result.actions.contains(.forward))
        XCTAssertTrue(result.actions.contains(.pin))
        XCTAssertTrue(result.actions.contains(.status))
    }

    func testForeignMessageHasNoEditDeleteOrStatus() {
        let message = TestData.message("m1", text: "hi", sender: "other")
            .replacing(messageId: 5)

        let result = MessageActionsBuilder.build(
            message: message,
            myUserUuid: "me",
            isGroupChat: true
        )

        XCTAssertFalse(result.actions.contains(.edit))
        XCTAssertFalse(result.actions.contains(.delete))
        XCTAssertFalse(result.actions.contains(.status))
        XCTAssertTrue(result.actions.contains(.reply))
        XCTAssertTrue(result.actions.contains(.forward))
    }

    func testPinnedMessageOffersUnpin() {
        let message = TestData.message("m1", text: "hi")
            .replacing(messageId: 5, isPinned: true)

        let result = MessageActionsBuilder.build(
            message: message,
            myUserUuid: "me",
            isGroupChat: false
        )

        XCTAssertTrue(result.actions.contains(.unpin))
        XCTAssertFalse(result.actions.contains(.pin))
        XCTAssertFalse(result.actions.contains(.status))
    }

    func testLocalMessageHasNoServerActions() {
        let local = TestData.message("local-1", text: "hi", createdAt: nil)
        let result = MessageActionsBuilder.build(
            message: local,
            myUserUuid: "me",
            isGroupChat: false
        )

        XCTAssertEqual(result.actions, [.react, .copy])
        XCTAssertFalse(result.showStatus)
    }

    func testDeletedMessageHasNoActions() {
        let message = TestData.message("m1").replacing(isDeleted: true)
        XCTAssertTrue(
            MessageActionsBuilder.build(message: message, myUserUuid: "me", isGroupChat: true)
                .actions.isEmpty
        )
    }
}

// MARK: - Mentions

extension ChatTextParityTests {

    func testResolvesTrailingMentionAndFilters() {
        let query = MentionSuggestions.resolve(
            text: "привет @al",
            usernames: ["alice", "bob", "alex"],
            limit: 6
        )

        XCTAssertEqual(query?.candidates, ["alice", "alex"])
    }

    func testIgnoresEmailAndWordPrefixedAt() {
        XCTAssertNil(MentionSuggestions.resolve(text: "mail@al", usernames: ["alice"]))
        XCTAssertNil(MentionSuggestions.resolve(text: "word@al", usernames: ["alice"]))
        XCTAssertNil(MentionSuggestions.resolve(text: "hi @al ice", usernames: ["alice"]))
    }

    func testAppliesMentionReplacingQuery() {
        let text = "привет @al"
        let query = MentionSuggestions.resolve(text: text, usernames: ["alice"])!

        let result = MentionSuggestions.apply("alice", to: text, query: query)

        XCTAssertEqual(result, "привет @alice ")
    }

    func testLimitIsRespected() {
        let query = MentionSuggestions.resolve(
            text: "@",
            usernames: ["a1", "a2", "a3", "a4"],
            limit: 2
        )
        XCTAssertEqual(query?.candidates.count, 2)
    }
}

// MARK: - Drafts and previews

extension ChatTextParityTests {

    func testDraftStoreRoundTripAndClearAll() {
        let defaults = UserDefaults(suiteName: "muzea-drafts-\(UUID().uuidString)")!
        let store = UserDefaultsChatDraftStore(defaults: defaults)

        store.save(chatUuid: "c1", text: "hello")
        XCTAssertEqual(store.draft(chatUuid: "c1"), "hello")

        store.save(chatUuid: "c2", text: "   ")
        XCTAssertNil(store.draft(chatUuid: "c2"))

        store.clearAll()
        XCTAssertNil(store.draft(chatUuid: "c1"))
    }

    func testReplyPreviewUsesYouAndDeletedNames() {
        let mine = TestData.message("m1", text: "hi", sender: "me")
        let deleted = TestData.message("m2", text: "hi", sender: "other")
            .replacing(senderDeleted: true)

        XCTAssertEqual(MessagePreviewText.senderName(mine, myUserUuid: "me"), "Вы")
        XCTAssertEqual(MessagePreviewText.senderName(deleted, myUserUuid: "me"), "Удалённый пользователь")
        XCTAssertEqual(MessagePreviewText.preview(mine), "hi")
    }

    func testPreviewFallsBackToMessageType() {
        let gif = TestData.message("m1", text: "").replacing(messageType: "GIF")
        XCTAssertEqual(MessagePreviewText.preview(gif), "GIF")
    }
}

// MARK: - ViewModel scenarios

@MainActor
final class ChatConversationTextViewModelTests: XCTestCase {

    private func makeViewModel(
        messages: [MessageResponse] = [],
        actions: FakeMessageActionsRepository = FakeMessageActionsRepository(),
        reactions: FakeMessageReactionRepository = FakeMessageReactionRepository(),
        drafts: FakeChatDraftStore = FakeChatDraftStore()
    ) -> (ChatConversationViewModel, FakeMessageRepository) {
        let repository = FakeMessageRepository()
        repository.cached = messages
        repository.messages = messages
        let services = ChatConversationServices.fake(
            messages: repository,
            actions: actions,
            reactions: reactions,
            drafts: drafts
        )
        return (
            ChatConversationViewModel(
                chatUuid: "c-1",
                myUserUuid: "me",
                isGroupChat: false,
                services: services
            ),
            repository
        )
    }

    func testSendCarriesReplyAndClientId() async {
        let original = TestData.message("orig", text: "first")
        let (viewModel, repository) = makeViewModel(messages: [original])
        viewModel.beginReply(to: original)

        await viewModel.send("reply")

        XCTAssertEqual(repository.sentRequests.last?.replyTo, "orig")
        XCTAssertNotNil(repository.sentRequests.last?.clientId)
        XCTAssertNil(viewModel.state.replyTo)
    }

    func testEditUpdatesExistingMessage() async {
        let original = TestData.message("m1", text: "old")
            .replacing(messageId: 5)
        let actions = FakeMessageActionsRepository()
        actions.editResult = original.replacing(text: "new", isEdited: true)
        let (viewModel, _) = makeViewModel(messages: [original], actions: actions)

        viewModel.beginEdit(original)
        await viewModel.send("new")

        XCTAssertEqual(actions.edited.first?.0, "m1")
        XCTAssertEqual(actions.edited.first?.1, "new")
        XCTAssertEqual(viewModel.state.messages.first?.text, "new")
        XCTAssertNil(viewModel.state.editing)
    }

    func testDeleteRemovesMessageAndClearsComposer() async {
        let original = TestData.message("m1", text: "bye")
            .replacing(messageId: 5)
        let actions = FakeMessageActionsRepository()
        let (viewModel, _) = makeViewModel(messages: [original], actions: actions)
        viewModel.beginReply(to: original)

        await viewModel.deleteMessage(original)

        XCTAssertEqual(actions.deleted, ["m1"])
        XCTAssertTrue(viewModel.state.messages.isEmpty)
        XCTAssertNil(viewModel.state.replyTo)
    }

    func testPinTogglesFlagAndRefreshesPanel() async {
        let original = TestData.message("m1", text: "pin me")
            .replacing(messageId: 5)
        let actions = FakeMessageActionsRepository()
        actions.pinnedMessages = [original.replacing(isPinned: true)]
        let (viewModel, _) = makeViewModel(messages: [original], actions: actions)

        await viewModel.togglePin(original)

        XCTAssertEqual(actions.pinned, [("c-1", "m1")])
        XCTAssertEqual(viewModel.state.messages.first?.isPinned, true)
        XCTAssertEqual(viewModel.state.pinned.count, 1)
    }

    func testReactionUpdatesMessageSnapshot() async {
        let original = TestData.message("m1", text: "react")
            .replacing(messageId: 5)
        let reactions = FakeMessageReactionRepository()
        reactions.reactions["m1"] = [
            MessageReactionResponse(emoji: "👍", count: 1, mine: true, users: [])
        ]
        let (viewModel, _) = makeViewModel(messages: [original], reactions: reactions)

        await viewModel.toggleReaction(original, emoji: "👍")

        XCTAssertEqual(reactions.toggles.first?.0, "m1")
        XCTAssertEqual(viewModel.state.messages.first?.reactions?.first?.emoji, "👍")
    }

    func testForwardSendsMessageAndCommentToTargetChat() async {
        let original = TestData.message("m1", text: "send me")
            .replacing(messageId: 5)
        let actions = FakeMessageActionsRepository()
        let (viewModel, repository) = makeViewModel(messages: [original], actions: actions)

        await viewModel.forward([original], toChatUuid: "c-2", comment: "look")

        XCTAssertEqual(actions.forwarded.first?.0, "m1")
        XCTAssertEqual(actions.forwarded.first?.1, "c-2")
        XCTAssertEqual(repository.sentRequests.last?.text, "look")
        XCTAssertEqual(viewModel.state.notice, "Переслано")
    }

    func testSelectionTracksMessages() {
        let first = TestData.message("m1", createdAt: "2026-01-01T00:00:01")
        let second = TestData.message("m2", createdAt: "2026-01-01T00:00:02")
        let (viewModel, _) = makeViewModel(messages: [first, second])

        viewModel.enterSelection(with: first)
        viewModel.toggleSelection(second)

        XCTAssertTrue(viewModel.state.isSelecting)
        XCTAssertEqual(viewModel.selectedMessages.map(\.messageUuid), ["m1", "m2"])

        viewModel.toggleSelection(first)
        viewModel.toggleSelection(second)
        XCTAssertFalse(viewModel.state.isSelecting)
    }

    func testInitialDraftComesFromStore() {
        let drafts = FakeChatDraftStore()
        drafts.storage["c-1"] = "draft text"
        let (viewModel, _) = makeViewModel(drafts: drafts)

        XCTAssertEqual(viewModel.initialDraft, "draft text")
    }
}
