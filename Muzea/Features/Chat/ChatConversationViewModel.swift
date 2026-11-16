import Foundation

/// Единое состояние экрана переписки.
struct ChatConversationUiState: Equatable {
    var messages: [MessageResponse] = []
    var isLoading = false
    var isLoadingMore = false
    var error: String?
    var notice: String?

    /// Сообщение, на которое сейчас отвечаем.
    var replyTo: MessageResponse?
    /// Сообщение, которое сейчас редактируем.
    var editing: MessageResponse?

    var pinned: [MessageResponse] = []
    var receipts: [ChatReceiptResponse] = []
    var receiptsLoaded = false
    /// Статусы собственных сообщений: uuid -> галочка.
    var statuses: [String: MessageDeliveryStatus] = [:]
    var failedMessages: Set<String> = []

    var selection: Set<String> = []
    var participants: [ChatParticipantResponse] = []
    var forwardChats: [ChatResponse] = []

    var isSelecting: Bool { !selection.isEmpty }
}

@MainActor
final class ChatConversationViewModel: ObservableObject {
    @Published private(set) var state = ChatConversationUiState()

    let chatUuid: String
    let myUserUuid: String?
    let isGroupChat: Bool

    private let services: ChatConversationServices
    private let reducer = ChatMessageReducer()
    private var lastMarkedReadUuid: String?
    private var lastMarkedDeliveredUuid: String?
    private var lastReceiptsRefreshAt: Date?
    private var pollTick = 0

    init(
        chatUuid: String,
        myUserUuid: String?,
        isGroupChat: Bool,
        services: ChatConversationServices
    ) {
        self.chatUuid = chatUuid
        self.myUserUuid = myUserUuid
        self.isGroupChat = isGroupChat
        self.services = services
        // Стартуем с кэша: при повторном входе переписка видна сразу, а опрос
        // догружает свежие сообщения фоном.
        state.messages = reducer.seed(services.messages.cachedMessages(chatUuid: chatUuid))
        recomputeStatuses()
    }

    var initialDraft: String {
        services.drafts.draft(chatUuid: chatUuid) ?? ""
    }

    var mentionCandidates: [String] {
        state.participants.compactMap { participant in
            let name = participant.username ?? participant.fullName
            guard let name, !name.isEmpty else { return nil }
            return name
        }
    }

    /// Опрос: первый запрос уходит сразу, поэтому отдельный refresh() при входе
    /// был бы вторым обращением к серверу подряд.
    func start() async {
        await refresh()
        await loadParticipantsIfNeeded()
        await refreshPinned()
        await refreshReceipts(force: true)

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: Config.chatPollInterval)
            guard !Task.isCancelled else { return }
            pollTick += 1
            if pollTick % 5 == 0 {
                // Полная сверка раз в 15 секунд: забирает удаления и реакции,
                // которые не приходят в /updated.
                await loadFull()
                await refreshPinned()
                await refreshReceipts()
            } else {
                await loadIncremental()
            }
        }
    }

    /// Разовая полная загрузка вне цикла опроса (pull-to-refresh, возврат).
    func refresh() async {
        await loadFull()
    }

    @discardableResult
    func send(_ text: String, power: Int = 0) async -> Bool {
        if let editing = state.editing {
            return await submitEdit(editing, text: text)
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let clampedPower = min(max(power, 0), 100)

        let replyToUuid = state.replyTo.map { reducer.serverUuid($0.messageUuid) }
        let optimistic = MessageResponse(
            messageUuid: "local-\(Int(Date().timeIntervalSince1970 * 1000))",
            messageId: nil,
            chatUuid: chatUuid,
            senderId: nil,
            senderUuid: myUserUuid,
            senderName: nil,
            senderAvatar: nil,
            text: trimmed,
            messageType: "TEXT",
            replyToMessageUuid: replyToUuid,
            forwardedFromMessageUuid: nil,
            forwardedFromUserUuid: nil,
            isEdited: false,
            isDeleted: false,
            isPinned: false,
            createdAt: nil,
            updatedAt: nil,
            reactions: [],
            power: clampedPower
        )
        merge([optimistic])
        state.replyTo = nil
        services.drafts.clear(chatUuid: chatUuid)

        do {
            let sent = try await services.messages.sendMessage(
                chatUuid: chatUuid,
                text: trimmed,
                replyToMessageUuid: replyToUuid,
                clientMessageId: UUID().uuidString,
                power: clampedPower
            )
            state.messages = reducer.applyServerEcho(
                current: state.messages,
                localUuid: optimistic.messageUuid,
                serverMessage: sent
            )
            recomputeStatuses()
            await markRead()
            await markDelivered()
            await refreshReceipts(force: true)
            return true
        } catch {
            state.failedMessages.insert(optimistic.messageUuid)
            state.error = error.localizedDescription
            recomputeStatuses()
            return false
        }
    }

    func beginReply(to message: MessageResponse) {
        state.replyTo = message
        state.editing = nil
    }

    func beginEdit(_ message: MessageResponse) {
        state.editing = message
        state.replyTo = nil
    }

    func cancelComposer() {
        state.replyTo = nil
        state.editing = nil
    }

    func deleteMessage(_ message: MessageResponse) async {
        let target = reducer.serverUuid(message.messageUuid)
        do {
            try await services.actions.deleteMessage(messageUuid: target)
            state.messages = reducer.removeMessage(current: state.messages, messageUuid: message.messageUuid)
            if state.replyTo?.messageUuid == message.messageUuid { state.replyTo = nil }
            if state.editing?.messageUuid == message.messageUuid { state.editing = nil }
            recomputeStatuses()
            await refreshPinned()
        } catch {
            state.error = error.localizedDescription
        }
    }

    func togglePin(_ message: MessageResponse) async {
        let target = reducer.serverUuid(message.messageUuid)
        let shouldUnpin = message.isPinned == true
        do {
            if shouldUnpin {
                try await services.actions.unpinMessage(chatUuid: chatUuid, messageUuid: target)
            } else {
                try await services.actions.pinMessage(chatUuid: chatUuid, messageUuid: target)
            }
            state.messages = reducer.updateMessage(
                current: state.messages,
                updated: message.replacing(isPinned: !shouldUnpin)
            )
            await refreshPinned()
        } catch {
            state.error = error.localizedDescription
        }
    }

    func toggleReaction(_ message: MessageResponse, emoji: String) async {
        let target = reducer.serverUuid(message.messageUuid)
        do {
            let reactions = try await services.reactions.toggleReaction(
                messageUuid: target,
                emoji: emoji
            )
            state.messages = reducer.updateMessage(
                current: state.messages,
                updated: message.replacing(reactions: reactions)
            )
        } catch {
            state.error = error.localizedDescription
        }
    }

    /// Пересылка одного сообщения с необязательным комментарием.
    func forward(
        _ message: MessageResponse,
        toChatUuid target: String,
        comment: String? = nil
    ) async {
        await forward(messages: [message], toChatUuid: target, comment: comment)
    }

    /// Пересылка пачки: комментарий уходит один раз после всех сообщений.
    func forward(
        messages: [MessageResponse],
        toChatUuid target: String,
        comment: String? = nil
    ) async {
        guard !messages.isEmpty else { return }
        var forwarded = false
        for message in messages {
            do {
                _ = try await services.actions.forwardMessage(
                    messageUuid: reducer.serverUuid(message.messageUuid),
                    toChatUuid: target
                )
                forwarded = true
            } catch {
                state.error = error.localizedDescription
            }
        }
        guard forwarded else { return }

        if let comment, !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                _ = try await services.messages.sendMessage(
                    chatUuid: target,
                    text: comment,
                    replyToMessageUuid: nil,
                    clientMessageId: UUID().uuidString,
                    power: 0
                )
            } catch {
                state.error = error.localizedDescription
            }
        }
        state.notice = "Переслано"
        exitSelection()
    }

    // MARK: - Selection

    func enterSelection(with message: MessageResponse) {
        state.selection = [message.messageUuid]
    }

    func toggleSelection(_ message: MessageResponse) {
        if state.selection.contains(message.messageUuid) {
            state.selection.remove(message.messageUuid)
        } else {
            state.selection.insert(message.messageUuid)
        }
    }

    func exitSelection() {
        state.selection = []
    }

    var selectedMessages: [MessageResponse] {
        state.messages.filter { state.selection.contains($0.messageUuid) }
    }

    func deleteSelected() async {
        let targets = selectedMessages
        for message in targets {
            await deleteMessage(message)
        }
        exitSelection()
    }

    // MARK: - Forward picker

    func loadForwardChats() async {
        do {
            state.forwardChats = try await services.chats.loadChats()
                .filter { $0.chatUuid != chatUuid }
        } catch {
            state.error = error.localizedDescription
        }
    }

    // MARK: - Errors / notices

    func consumeError() {
        state.error = nil
    }

    func consumeNotice() {
        state.notice = nil
    }

    func saveDraft(_ text: String) {
        services.drafts.save(chatUuid: chatUuid, text: text)
    }

    // MARK: - Loading

    private func loadFull() async {
        if state.messages.isEmpty { state.isLoading = true }
        do {
            let loaded = try await services.messages.loadMessages(chatUuid: chatUuid)
            state.isLoading = false
            state.error = nil
            merge(loaded)
            await markRead()
            await markDelivered()
        } catch {
            state.isLoading = false
            state.error = error.localizedDescription
        }
    }

    private func loadIncremental() async {
        guard let watermark = newestTimestamp else {
            await loadFull()
            return
        }
        do {
            let loaded = try await services.messages.loadMessagesAfter(
                chatUuid: chatUuid,
                timestamp: watermark
            )
            guard !loaded.isEmpty else { return }
            merge(loaded)
            await markRead()
            await refreshReceipts()
        } catch {
            // Инкрементальный опрос не должен затирать уже показанную переписку.
        }
    }

    private func loadParticipantsIfNeeded() async {
        guard isGroupChat else { return }
        state.participants = (try? await services.chats.loadChatParticipants(chatUuid: chatUuid)) ?? []
    }

    private func refreshPinned() async {
        do {
            state.pinned = try await services.actions.loadPinned(chatUuid: chatUuid)
        } catch {
            // Панель не критична для чтения переписки; оставляем прошлое значение.
        }
    }

    private func refreshReceipts(force: Bool = false) async {
        let now = Date()
        if !force, let last = lastReceiptsRefreshAt,
           now.timeIntervalSince(last) < 15 {
            return
        }
        do {
            state.receipts = try await services.receipts.loadReceipts(chatUuid: chatUuid)
            state.receiptsLoaded = true
            lastReceiptsRefreshAt = now
            recomputeStatuses()
        } catch {
            // Галочки просто останутся на прошлом значении.
        }
    }

    private func submitEdit(_ target: MessageResponse, text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state.error = "Сообщение не может быть пустым"
            return false
        }
        state.editing = nil
        guard trimmed != target.text else { return true }

        do {
            let updated = try await services.actions.editMessage(
                messageUuid: reducer.serverUuid(target.messageUuid),
                text: trimmed
            )
            let displayUuid = reducer.localUuidFor(updated.messageUuid) ?? updated.messageUuid
            let existing = state.messages.first { $0.messageUuid == displayUuid }
            let merged = updated
                .withMessageUuid(displayUuid)
                .replacing(reactions: updated.reactions ?? existing?.reactions ?? [])
            state.messages = reducer.updateMessage(current: state.messages, updated: merged)
            await refreshPinned()
            return true
        } catch {
            state.editing = target
            state.error = error.localizedDescription
            return false
        }
    }

    private func merge(_ incoming: [MessageResponse]) {
        state.messages = reducer.merge(current: state.messages, incoming: incoming)
        recomputeStatuses()
    }

    private func recomputeStatuses() {
        state.statuses = MessageStatusCalculator.statuses(
            messages: state.messages,
            receipts: state.receipts,
            myUserUuid: myUserUuid,
            failedMessages: state.failedMessages,
            receiptsLoaded: state.receiptsLoaded
        )
    }

    private var newestTimestamp: String? {
        state.messages
            .compactMap { message -> String? in
                guard message.messageUuid.hasPrefix("local-") == false,
                      let createdAt = message.createdAt,
                      !createdAt.isEmpty else { return nil }
                return createdAt
            }
            .max()
    }

    private func markRead() async {
        let latest = state.messages.last {
            !$0.messageUuid.isEmpty && !$0.messageUuid.hasPrefix("local-")
        }
        guard let latest, latest.messageUuid != lastMarkedReadUuid else { return }
        lastMarkedReadUuid = latest.messageUuid
        await services.messages.markMessagesAsRead(
            chatUuid: chatUuid,
            upToMessageUuid: reducer.serverUuid(latest.messageUuid)
        )
    }

    private func markDelivered() async {
        let latest = state.messages.last {
            $0.messageId != nil && !$0.messageUuid.hasPrefix("local-")
        }
        guard let latest, latest.messageUuid != lastMarkedDeliveredUuid else { return }
        lastMarkedDeliveredUuid = latest.messageUuid
        await services.messages.markMessagesAsDelivered(
            chatUuid: chatUuid,
            upToMessageUuid: reducer.serverUuid(latest.messageUuid)
        )
    }
}
