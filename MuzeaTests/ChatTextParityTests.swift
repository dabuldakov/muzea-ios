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
    ) -> ChatReceipt {
        ChatReceipt(
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
    ) -> ChatMessage {
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
        let local = TestData.message("local-1", createdAt: nil, sender: "me")
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
        XCTAssertTrue(result.actions.contains(.report))
        XCTAssertTrue(result.actions.contains(.block))
    }

    func testForeignMessageWithReactionsOffersDetails() {
        let reaction = MessageReaction(
            emoji: "👍",
            count: 1,
            mine: false,
            users: [ReactionUser(userUuid: "u2", at: "2026-01-01T00:00:03")]
        )
        let message = TestData.message("m1", text: "hi", sender: "other")
            .replacing(messageId: 5, reactions: [reaction])

        let result = MessageActionsBuilder.build(
            message: message,
            myUserUuid: "me",
            isGroupChat: false
        )

        XCTAssertTrue(result.actions.contains(.status))
        XCTAssertFalse(result.showStatus)
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

    func testFailedLocalMessageOffersRetry() {
        let local = TestData.message("local-1", text: "hi", createdAt: nil)
        let result = MessageActionsBuilder.build(
            message: local,
            myUserUuid: "me",
            isGroupChat: false,
            failedMessages: ["local-1"]
        )

        XCTAssertTrue(result.actions.contains(.retry))
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

    func testReactionHistoryKeepsRecentFirstAndCaps() {
        let defaults = UserDefaults(suiteName: "muzea-reactions-\(UUID().uuidString)")!
        let store = UserDefaultsReactionHistoryStore(defaults: defaults)

        XCTAssertEqual(store.recent().count, ReactionCatalog.recentLimit)
        store.record("🚀")
        store.record("🔥")
        store.record("🚀")

        XCTAssertEqual(store.recent().prefix(2), ["🚀", "🔥"])
    }

    func testFileOutboxRoundTripAndRemove() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("outbox-\(UUID().uuidString).json")
        let store = FileChatOutboxStore(fileURL: url)
        let item = PendingChatMessage(
            clientMessageId: "client-1",
            localUuid: "local-1",
            chatUuid: "c1",
            text: "queued",
            replyToMessageUuid: nil,
            power: 0,
            createdAt: "2026-01-01T00:00:01"
        )

        store.save(item)
        XCTAssertEqual(store.pending(chatUuid: "c1"), [item])
        XCTAssertTrue(store.pending(chatUuid: "other").isEmpty)

        store.remove(clientMessageId: "client-1")
        XCTAssertTrue(store.pending(chatUuid: "c1").isEmpty)

        store.save(item)
        store.clearAll()
        XCTAssertTrue(store.pending(chatUuid: "c1").isEmpty)
    }

    func testReplyPreviewUsesYouAndDeletedNames() {
        let mine = TestData.message("m1", text: "hi", sender: "me")
        let deleted = TestData.message("m2", text: "hi", sender: "other")
            .replacing(senderDeleted: true)

        XCTAssertEqual(MessagePreviewText.senderName(mine, myUserUuid: "me"), L10n.you)
        XCTAssertEqual(MessagePreviewText.senderName(deleted, myUserUuid: "me"), L10n.deletedUser)
        XCTAssertEqual(MessagePreviewText.preview(mine), "hi")
    }

    func testPreviewFallsBackToMessageType() {
        let gif = TestData.message("m1", text: "").replacing(messageType: "GIF")
        XCTAssertEqual(MessagePreviewText.preview(gif), "GIF")
    }
}

// MARK: - Charge

extension ChatTextParityTests {

    func testChargePowerGrowsToHundredAndClamps() {
        XCTAssertEqual(ChargeCalculator.power(elapsed: -1), 0)
        XCTAssertEqual(ChargeCalculator.power(elapsed: 0.5), 0)
        XCTAssertEqual(ChargeCalculator.power(elapsed: 1), 0)
        // sqrt(29/59) ≈ 0.70 -> 70
        XCTAssertEqual(ChargeCalculator.power(elapsed: 30), 70)
        XCTAssertEqual(ChargeCalculator.power(elapsed: 60), 100)
        XCTAssertEqual(ChargeCalculator.power(elapsed: 120), 100)
    }

    func testChargeCancelsOnlyOnSwipeUp() {
        XCTAssertTrue(ChargeCalculator.isCancelled(translationY: -80))
        XCTAssertFalse(ChargeCalculator.isCancelled(translationY: -10))
        XCTAssertFalse(ChargeCalculator.isCancelled(translationY: 80))
    }

    func testHapticLevelSteps() {
        XCTAssertEqual(ChargeCalculator.hapticLevel(power: 0), 0)
        XCTAssertEqual(ChargeCalculator.hapticLevel(power: 24), 0)
        XCTAssertEqual(ChargeCalculator.hapticLevel(power: 25), 1)
        XCTAssertEqual(ChargeCalculator.hapticLevel(power: 100), 4)
    }
}

// MARK: - Link previews

extension ChatTextParityTests {

    func testExtractsFirstURLAndStripsTrailingPunctuation() {
        XCTAssertEqual(
            LinkPreviewExtractor.firstURL(in: "look https://example.com/a?b=1, ok")?.absoluteString,
            "https://example.com/a?b=1"
        )
        XCTAssertNil(LinkPreviewExtractor.firstURL(in: "no links here"))
    }

    func testParsesOpenGraphRegardlessOfAttributeOrder() {
        let html = """
        <html><head>
        <meta content="Site" property="og:site_name">
        <meta property="og:title" content="Hello &amp; world">
        <meta property="og:description" content="Desc">
        <meta property="og:image" content="/img.png">
        </head></html>
        """

        let preview = LinkPreviewParser.parse(
            html,
            baseURL: URL(string: "https://example.com/page")!
        )

        XCTAssertEqual(preview?.title, "Hello & world")
        XCTAssertEqual(preview?.description, "Desc")
        XCTAssertEqual(preview?.siteName, "Site")
        XCTAssertEqual(preview?.imageURL?.absoluteString, "https://example.com/img.png")
    }

    func testFallsBackToTitleTag() {
        let html = "<html><head><title>Plain title</title></head></html>"
        let preview = LinkPreviewParser.parse(
            html,
            baseURL: URL(string: "https://example.com")!
        )
        XCTAssertEqual(preview?.title, "Plain title")
    }

    func testBlocksLocalAndPrivateHosts() {
        XCTAssertTrue(LinkPreviewSafety.isBlockedHost("localhost"))
        XCTAssertTrue(LinkPreviewSafety.isBlockedHost("metadata.google.internal"))
        XCTAssertTrue(LinkPreviewSafety.isBlockedHost("192.168.1.5"))
        XCTAssertTrue(LinkPreviewSafety.isBlockedHost("10.0.0.1"))
        XCTAssertTrue(LinkPreviewSafety.isBlockedHost("127.0.0.1"))
        XCTAssertTrue(LinkPreviewSafety.isBlockedHost("intranet"))
        XCTAssertFalse(LinkPreviewSafety.isBlockedHost("8.8.8.8"))
        XCTAssertFalse(LinkPreviewSafety.isBlockedHost("example.com"))
    }

    func testUnsafeSchemesAndHostsAreRejected() {
        XCTAssertFalse(LinkPreviewSafety.isSafe(URL(string: "file:///etc/passwd")!))
        XCTAssertFalse(LinkPreviewSafety.isSafe(URL(string: "https://127.0.0.1/")!))
        XCTAssertTrue(LinkPreviewSafety.isSafe(URL(string: "https://8.8.8.8/")!))
    }
}

// MARK: - ViewModel scenarios

@MainActor
final class ChatConversationTextViewModelTests: XCTestCase {

    func testLoadOlderMessagesPrependsAndStopsOnShortPage() async {
        let newest = TestData.message("m3", createdAt: "2026-01-01T00:00:03")
        let (viewModel, repository) = makeViewModel(messages: [newest])
        repository.olderMessages = [
            TestData.message("m1", createdAt: "2026-01-01T00:00:01"),
            TestData.message("m2", createdAt: "2026-01-01T00:00:02")
        ]

        await viewModel.loadOlderMessages()

        XCTAssertEqual(viewModel.state.messages.map(\.messageUuid), ["m1", "m2", "m3"])
        XCTAssertEqual(repository.requestedBefore.first?.beforeUuid, "m3")
        XCTAssertFalse(viewModel.state.hasMoreHistory)
        XCTAssertFalse(viewModel.state.isLoadingMore)
    }

    func testLoadOlderMessagesKeepsPagingWhenPageIsFull() async {
        let newest = TestData.message("m-new", createdAt: "2026-01-02T00:00:00")
        let (viewModel, repository) = makeViewModel(messages: [newest])
        repository.olderMessages = (0..<Config.messagePageSize).map { index in
            TestData.message(
                "old-\(index)",
                createdAt: String(format: "2026-01-01T00:00:%02d", index)
            )
        }

        await viewModel.loadOlderMessages()

        XCTAssertTrue(viewModel.state.hasMoreHistory)
        XCTAssertEqual(viewModel.state.messages.first?.messageUuid, "old-0")
        XCTAssertEqual(viewModel.state.messages.last?.messageUuid, "m-new")
    }

    func testLoadOlderMessagesSkipsWhenOnlyLocalMessages() async {
        let (viewModel, repository) = makeViewModel(messages: [])

        await viewModel.loadOlderMessages()

        XCTAssertTrue(repository.requestedBefore.isEmpty)
        XCTAssertTrue(viewModel.state.messages.isEmpty)
    }

    func testLoadOlderMessagesStopsWhenServerRepeatsKnownMessages() async {
        let newest = TestData.message("m1", createdAt: "2026-01-01T00:00:01")
        let (viewModel, repository) = makeViewModel(messages: [newest])
        repository.olderMessages = [newest]

        await viewModel.loadOlderMessages()

        XCTAssertEqual(viewModel.state.messages.map(\.messageUuid), ["m1"])
        XCTAssertFalse(viewModel.state.hasMoreHistory)
    }

    func testLoadOlderMessagesKeepsHistoryOnError() async {
        let newest = TestData.message("m1", createdAt: "2026-01-01T00:00:01")
        let (viewModel, repository) = makeViewModel(messages: [newest])
        repository.olderError = APIError.server(500, "boom")

        await viewModel.loadOlderMessages()

        XCTAssertEqual(viewModel.state.messages.map(\.messageUuid), ["m1"])
        XCTAssertTrue(viewModel.state.hasMoreHistory)
        XCTAssertFalse(viewModel.state.isLoadingMore)
        XCTAssertNil(viewModel.state.error)
    }

    func testStartLoadsParticipantsAndStopsOnCancel() async {
        let (viewModel, _) = makeViewModel()

        let task = Task { await viewModel.start() }
        try? await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()

        XCTAssertEqual(viewModel.mentionCandidates, [])
        XCTAssertFalse(viewModel.recentReactions.isEmpty)
    }

    func testRetryFailedMessageClearsFailure() async throws {
        let (viewModel, repository) = makeViewModel()
        repository.sendError = APIError.server(500, "boom")
        _ = await viewModel.send("hello")
        let failed = try XCTUnwrap(viewModel.state.messages.first)
        XCTAssertTrue(viewModel.state.failedMessages.contains(failed.messageUuid))

        repository.sendError = nil
        await viewModel.retry(failed)

        XCTAssertFalse(viewModel.state.failedMessages.contains(failed.messageUuid))
    }

    func testVideoAttachmentCanBeRemovedBeforeSend() async throws {
        let (viewModel, _) = makeViewModel()

        await viewModel.addVideo(data: Data([1, 2]), fileName: "clip.mp4", duration: 5)
        let pending = try XCTUnwrap(viewModel.state.pendingAttachments.first)
        XCTAssertEqual(pending.kind, .video)

        viewModel.removePendingAttachment(pending.id)
        XCTAssertTrue(viewModel.state.pendingAttachments.isEmpty)
        XCTAssertFalse(viewModel.state.isUploadingAttachments)
    }

    func testComposerDraftAndNotices() async {
        let drafts = FakeChatDraftStore()
        let (viewModel, _) = makeViewModel(drafts: drafts)

        viewModel.saveDraft("черновик")
        XCTAssertEqual(drafts.storage["c-1"], "черновик")

        viewModel.reportValidationError("bad")
        XCTAssertEqual(viewModel.state.error, "bad")
        viewModel.consumeError()
        XCTAssertNil(viewModel.state.error)

        viewModel.consumeNotice()
        XCTAssertNil(viewModel.state.notice)

        viewModel.beginReply(to: TestData.message("m1"))
        XCTAssertNotNil(viewModel.state.replyTo)
        viewModel.cancelComposer()
        XCTAssertNil(viewModel.state.replyTo)
    }

    func testSingleForwardAndForwardChatsLoad() async throws {
        let original = TestData.message("m1", text: "send me").replacing(messageId: 5)
        let actions = FakeMessageActionsRepository()
        let chats = FakeChatRepository()
        chats.chats = [TestData.chat("c-2")]
        let (viewModel, repository) = makeViewModel(
            messages: [original],
            actions: actions,
            chats: chats
        )

        await viewModel.loadForwardChats()
        XCTAssertEqual(viewModel.state.forwardChats.map(\.chatUuid), ["c-2"])

        await viewModel.forward(original, toChatUuid: "c-2", comment: "look")
        XCTAssertEqual(actions.forwarded.first?.0, "m1")
        XCTAssertEqual(repository.sentRequests.last?.text, "look")
        XCTAssertEqual(viewModel.state.notice, L10n.forwarded)
    }

    private func makeViewModel(
        messages: [ChatMessage] = [],
        actions: FakeMessageActionsRepository = FakeMessageActionsRepository(),
        reactions: FakeMessageReactionRepository = FakeMessageReactionRepository(),
        statuses: FakeMessageStatusRepository = FakeMessageStatusRepository(),
        moderation: FakeModerationRepository = FakeModerationRepository(),
        drafts: FakeChatDraftStore = FakeChatDraftStore(),
        reactionHistory: FakeReactionHistoryStore = FakeReactionHistoryStore(),
        outbox: FakeChatOutboxStore = FakeChatOutboxStore(),
        chats: FakeChatRepository = FakeChatRepository()
    ) -> (ChatConversationViewModel, FakeMessageRepository) {
        let repository = FakeMessageRepository()
        repository.cached = messages
        repository.messages = messages
        let services = ChatConversationServices.fake(
            messages: repository,
            actions: actions,
            reactions: reactions,
            statuses: statuses,
            moderation: moderation,
            drafts: drafts,
            reactionHistory: reactionHistory,
            outbox: outbox,
            chats: chats
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

    func testSendPassesChargePower() async {
        let (viewModel, repository) = makeViewModel()

        await viewModel.send("charged", power: 55)

        XCTAssertEqual(repository.sentRequests.last?.power, 55)
        XCTAssertEqual(viewModel.state.messages.first?.power, 55)
    }

    func testFailedSendKeepsFailedBubbleAndQueuesIt() async {
        let outbox = FakeChatOutboxStore()
        let (viewModel, repository) = makeViewModel(outbox: outbox)
        repository.sendError = APIError.server(500, "boom")

        let ok = await viewModel.send("lost")

        XCTAssertFalse(ok)
        XCTAssertEqual(viewModel.state.messages.count, 1)
        let uuid = viewModel.state.messages.first?.messageUuid
        XCTAssertEqual(uuid?.hasPrefix("local-"), true)
        XCTAssertEqual(outbox.items.count, 1)
        XCTAssertEqual(outbox.items.first?.text, "lost")
        XCTAssertTrue(uuid.map { viewModel.state.failedMessages.contains($0) } ?? false)
        XCTAssertEqual(uuid.flatMap { viewModel.state.statuses[$0] }, MessageDeliveryStatus.failed)
    }

    func testRetryPendingSendsQueuedMessage() async {
        let outbox = FakeChatOutboxStore()
        let (viewModel, repository) = makeViewModel(outbox: outbox)
        repository.sendError = APIError.server(500, "boom")
        _ = await viewModel.send("lost")
        XCTAssertEqual(outbox.items.count, 1)

        repository.sendError = nil
        await viewModel.retryPending(force: true)

        XCTAssertTrue(outbox.items.isEmpty)
        XCTAssertTrue(viewModel.state.failedMessages.isEmpty)
        XCTAssertEqual(viewModel.state.messages.count, 1)
    }

    func testInitRestoresPendingBubble() {
        let outbox = FakeChatOutboxStore()
        outbox.items = [
            PendingChatMessage(
                clientMessageId: "client-1",
                localUuid: "local-1",
                chatUuid: "c-1",
                text: "queued",
                replyToMessageUuid: nil,
                power: 0,
                createdAt: "2026-01-01T00:00:01"
            )
        ]
        let (viewModel, _) = makeViewModel(outbox: outbox)

        XCTAssertEqual(viewModel.state.messages.first?.text, "queued")
        XCTAssertTrue(viewModel.state.failedMessages.contains("local-1"))
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

        XCTAssertEqual(actions.pinned.count, 1)
        XCTAssertEqual(actions.pinned.first?.0, "c-1")
        XCTAssertEqual(actions.pinned.first?.1, "m1")
        XCTAssertEqual(viewModel.state.messages.first?.isPinned, true)
        XCTAssertEqual(viewModel.state.pinned.count, 1)
    }

    func testReactionUpdatesMessageSnapshot() async {
        let original = TestData.message("m1", text: "react")
            .replacing(messageId: 5)
        let reactions = FakeMessageReactionRepository()
        reactions.reactions["m1"] = [
            MessageReaction(emoji: "👍", count: 1, mine: true, users: [])
        ]
        let history = FakeReactionHistoryStore()
        let (viewModel, _) = makeViewModel(
            messages: [original],
            reactions: reactions,
            reactionHistory: history
        )

        await viewModel.toggleReaction(original, emoji: "👍")

        XCTAssertEqual(reactions.toggles.first?.0, "m1")
        XCTAssertEqual(viewModel.state.messages.first?.reactions?.first?.emoji, "👍")
        XCTAssertEqual(history.emojis.first, "👍")
    }

    func testLoadMessageStatusesStoresExactTimes() async {
        let original = TestData.message("m1", text: "status")
            .replacing(messageId: 5)
        let statuses = FakeMessageStatusRepository()
        statuses.statuses["m1"] = [
            MessageStatus(
                userId: 7,
                userUuid: "u1",
                status: "READ",
                deliveredAt: "2026-01-01T00:00:05",
                readAt: "2026-01-01T00:00:06"
            )
        ]
        let (viewModel, _) = makeViewModel(messages: [original], statuses: statuses)

        await viewModel.loadMessageStatuses(for: original)

        XCTAssertEqual(statuses.loads.first?.1, "m1")
        XCTAssertEqual(viewModel.state.messageStatuses["m1"]?.first?.readAt, "2026-01-01T00:00:06")
    }

    func testReportAndBlockCallModeration() async {
        let foreign = TestData.message("m1", text: "spam", sender: "other")
            .replacing(messageId: 5)
        let moderation = FakeModerationRepository()
        let (viewModel, _) = makeViewModel(messages: [foreign], moderation: moderation)

        await viewModel.report(foreign, reason: "SPAM")
        await viewModel.block(userUuid: "other")

        XCTAssertEqual(moderation.reports.first?.0, "m1")
        XCTAssertEqual(moderation.reports.first?.1, "SPAM")
        XCTAssertEqual(moderation.blocks.first?.0, "other")
        XCTAssertEqual(viewModel.state.notice, L10n.noticeBlocked)
    }

    func testForwardSendsMessageAndCommentToTargetChat() async {
        let original = TestData.message("m1", text: "send me")
            .replacing(messageId: 5)
        let actions = FakeMessageActionsRepository()
        let (viewModel, repository) = makeViewModel(messages: [original], actions: actions)

        await viewModel.forward(messages: [original], toChatUuid: "c-2", comment: "look")

        XCTAssertEqual(actions.forwarded.first?.0, "m1")
        XCTAssertEqual(actions.forwarded.first?.1, "c-2")
        XCTAssertEqual(repository.sentRequests.last?.text, "look")
        XCTAssertEqual(viewModel.state.notice, L10n.forwarded)
    }

    func testDeleteSelectedSkipsForeignMessages() async {
        let mine = TestData.message("m1", text: "mine")
            .replacing(messageId: 1)
        let foreign = TestData.message("m2", text: "foreign", sender: "other")
            .replacing(messageId: 2)
        let actions = FakeMessageActionsRepository()
        let (viewModel, _) = makeViewModel(messages: [mine, foreign], actions: actions)

        viewModel.enterSelection(with: mine)
        viewModel.toggleSelection(foreign)
        await viewModel.deleteSelected()

        XCTAssertEqual(actions.deleted, ["m1"])
        XCTAssertFalse(viewModel.state.isSelecting)
    }

    func testSelectionTracksMessages() {        let first = TestData.message("m1", createdAt: "2026-01-01T00:00:01")
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
