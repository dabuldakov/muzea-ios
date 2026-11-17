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
    /// Точные статусы по сообщению, загруженные при открытии «Деталей».
    var messageStatuses: [String: [MessageStatusResponse]] = [:]
    /// Статусы собственных сообщений: uuid -> галочка.
    var statuses: [String: MessageDeliveryStatus] = [:]
    var failedMessages: Set<String> = []

    var selection: Set<String> = []
    var participants: [ChatParticipantResponse] = []
    var forwardChats: [ChatResponse] = []
    /// Выбранные вложения, ожидающие загрузки или уже загруженные.
    var pendingAttachments: [PendingChatAttachment] = []
    var isUploadingAttachments = false

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
    private var lastMarkedReadMessageId: Int64 = 0
    private var lastMarkedDeliveredUuid: String?
    private var lastReceiptsRefreshAt: Date?
    private var lastOutboxRetryAt: Date?
    private var retryingPending = false
    private var inFlightClientIds: Set<String> = []
    private var pollTick = 0

    private static let pendingDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

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
        let cached = reducer.seed(services.messages.cachedMessages(chatUuid: chatUuid))
        let pending = services.outbox.pending(chatUuid: chatUuid)
        state.messages = reducer.merge(
            current: cached,
            incoming: pending.map(pendingResponse)
        )
        state.failedMessages = Set(pending.map(\.localUuid))
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

    var recentReactions: [String] {
        services.reactionHistory.recent()
    }

    /// Опрос: первый запрос уходит сразу, поэтому отдельный refresh() при входе
    /// был бы вторым обращением к серверу подряд.
    func start() async {
        await refresh()
        await retryPending(force: true)
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
                await retryPending()
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
        let uploaded = state.pendingAttachments.compactMap(\.uploaded)
        guard !trimmed.isEmpty || !uploaded.isEmpty else { return false }
        guard state.pendingAttachments.allSatisfy(\.isUploaded) else {
            state.error = "Дождитесь загрузки вложений"
            return false
        }
        let kinds = state.pendingAttachments.map(\.kind)
        let messageType = AttachmentPolicy.messageType(for: kinds)
        let attachmentUuids = uploaded.compactMap(\.attachmentUuid)
        let clampedPower = min(max(power, 0), 100)

        let replyToUuid = state.replyTo.map { reducer.serverUuid($0.messageUuid) }
        let clientMessageId = UUID().uuidString
        let optimistic = MessageResponse(
            messageUuid: "local-\(Int(Date().timeIntervalSince1970 * 1000))",
            messageId: nil,
            chatUuid: chatUuid,
            senderId: nil,
            senderUuid: myUserUuid,
            senderName: nil,
            senderAvatar: nil,
            text: trimmed.isEmpty ? nil : trimmed,
            messageType: messageType,
            replyToMessageUuid: replyToUuid,
            forwardedFromMessageUuid: nil,
            forwardedFromUserUuid: nil,
            isEdited: false,
            isDeleted: false,
            isPinned: false,
            createdAt: Self.pendingDateFormatter.string(from: Date()),
            updatedAt: nil,
            reactions: [],
            power: clampedPower,
            attachments: uploaded
        )
        let pending = PendingChatMessage(
            clientMessageId: clientMessageId,
            localUuid: optimistic.messageUuid,
            chatUuid: chatUuid,
            text: trimmed,
            replyToMessageUuid: replyToUuid,
            power: clampedPower,
            createdAt: optimistic.createdAt ?? "",
            messageType: messageType,
            attachments: uploaded
        )
        merge([optimistic])
        state.replyTo = nil
        services.drafts.clear(chatUuid: chatUuid)

        do {
            inFlightClientIds.insert(clientMessageId)
            defer { inFlightClientIds.remove(clientMessageId) }
            let sent = try await services.messages.sendMessage(
                chatUuid: chatUuid,
                text: trimmed,
                messageType: messageType,
                replyToMessageUuid: replyToUuid,
                clientMessageId: clientMessageId,
                attachments: attachmentUuids,
                power: clampedPower
            )
            services.outbox.remove(clientMessageId: clientMessageId)
            state.pendingAttachments.removeAll()
            state.messages = reducer.applyServerEcho(
                current: state.messages,
                localUuid: optimistic.messageUuid,
                serverMessage: sent
            )
            state.failedMessages.remove(optimistic.messageUuid)
            recomputeStatuses()
            await markDelivered()
            await refreshReceipts(force: true)
            return true
        } catch {
            // Сообщение остаётся в ленте с пометкой «не отправлено» и попадает
            // в дисковую очередь: повтор идемпотентен по clientMessageId.
            services.outbox.save(pending)
            state.pendingAttachments.removeAll()
            state.failedMessages.insert(optimistic.messageUuid)
            state.error = error.localizedDescription
            recomputeStatuses()
            return false
        }
    }

    /// Ручной повтор неудачной отправки.
    func retry(_ message: MessageResponse) async {
        guard message.messageUuid.hasPrefix("local-"),
              let pending = services.outbox.pending(chatUuid: chatUuid)
                .first(where: { $0.localUuid == message.messageUuid }) else {
            return
        }
        await sendPending(pending)
    }

    /// Автоповтор дисковой очереди: при входе в чат и раз в 15 секунд.
    func retryPending(force: Bool = false) async {
        guard !retryingPending else { return }
        let now = Date()
        if !force, let last = lastOutboxRetryAt, now.timeIntervalSince(last) < 15 {
            return
        }
        let pending = services.outbox.pending(chatUuid: chatUuid)
        guard !pending.isEmpty else { return }

        retryingPending = true
        lastOutboxRetryAt = now
        defer { retryingPending = false }

        for item in pending {
            await sendPending(item)
        }
    }

    private func sendPending(_ pending: PendingChatMessage) async {
        guard !inFlightClientIds.contains(pending.clientMessageId) else { return }
        inFlightClientIds.insert(pending.clientMessageId)
        defer { inFlightClientIds.remove(pending.clientMessageId) }

        do {
            let sent = try await services.messages.sendMessage(
                chatUuid: chatUuid,
                text: pending.text,
                messageType: pending.messageType ?? "TEXT",
                replyToMessageUuid: pending.replyToMessageUuid,
                clientMessageId: pending.clientMessageId,
                attachments: (pending.attachments ?? []).compactMap(\.attachmentUuid),
                power: pending.power
            )
            services.outbox.remove(clientMessageId: pending.clientMessageId)
            state.failedMessages.remove(pending.localUuid)
            state.messages = reducer.applyServerEcho(
                current: state.messages,
                localUuid: pending.localUuid,
                serverMessage: sent
            )
            recomputeStatuses()
            await markDelivered()
        } catch {
            state.failedMessages.insert(pending.localUuid)
            recomputeStatuses()
        }
    }

    func beginReply(to message: MessageResponse) {
        state.replyTo = message
        state.editing = nil
    }

    // MARK: - Attachments

    func addImage(data: Data, fileName: String = "photo.jpg", width: Int?, height: Int?) async {
        await upload(
            data: data,
            fileName: fileName,
            mimeType: "image/jpeg",
            kind: .image,
            thumbnail: nil,
            width: width,
            height: height,
            duration: nil
        )
    }

    func addFile(data: Data, fileName: String, mimeType: String) async {
        await upload(
            data: data,
            fileName: fileName,
            mimeType: mimeType,
            kind: .document,
            thumbnail: nil,
            width: nil,
            height: nil,
            duration: nil
        )
    }

    func addVideo(data: Data, fileName: String, duration: Int?) async {
        let rule = AttachmentPolicy.rule(for: fileName)
        await upload(
            data: data,
            fileName: fileName,
            mimeType: rule?.mimeType ?? "video/mp4",
            kind: .video,
            thumbnail: nil,
            width: nil,
            height: nil,
            duration: duration
        )
    }

    func addAudio(data: Data, fileName: String, duration: Int?) async {
        let rule = AttachmentPolicy.rule(for: fileName)
        await upload(
            data: data,
            fileName: fileName,
            mimeType: rule?.mimeType ?? "audio/mpeg",
            kind: .audio,
            thumbnail: nil,
            width: nil,
            height: nil,
            duration: duration
        )
    }

    @discardableResult
    func sendVoice(_ recorded: RecordedVoice) async -> Bool {
        await addAudio(
            data: recorded.data,
            fileName: recorded.url.lastPathComponent,
            duration: recorded.duration
        )
        guard state.pendingAttachments.contains(where: \.isUploaded) else { return false }
        return await send("")
    }

    func removePendingAttachment(_ id: String) {
        state.pendingAttachments.removeAll { $0.id == id }
    }

    private func upload(
        data: Data,
        fileName: String,
        mimeType: String,
        kind: AttachmentKind,
        thumbnail: Data?,
        width: Int?,
        height: Int?,
        duration: Int?
    ) async {
        guard state.pendingAttachments.count < AttachmentPolicy.maxAttachmentsPerMessage else {
            state.error = "Можно прикрепить не больше \(AttachmentPolicy.maxAttachmentsPerMessage) файлов"
            return
        }
        if let message = AttachmentPolicy.validationError(
            fileName: fileName,
            size: Int64(data.count)
        ) {
            state.error = message
            return
        }

        let pending = PendingChatAttachment(
            id: UUID().uuidString,
            fileName: fileName,
            kind: kind,
            uploaded: nil
        )
        state.pendingAttachments.append(pending)
        state.isUploadingAttachments = true

        do {
            let uploaded = try await services.attachments.upload(
                chatUuid: chatUuid,
                data: data,
                fileName: fileName,
                mimeType: mimeType,
                kind: kind,
                thumbnail: thumbnail,
                width: width,
                height: height,
                duration: duration
            )
            if let index = state.pendingAttachments.firstIndex(where: { $0.id == pending.id }) {
                state.pendingAttachments[index].uploaded = uploaded
            }
        } catch {
            state.pendingAttachments.removeAll { $0.id == pending.id }
            state.error = error.localizedDescription
        }
        state.isUploadingAttachments = state.pendingAttachments.contains { !$0.isUploaded }
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
            services.reactionHistory.record(emoji)
        } catch {
            state.error = error.localizedDescription
        }
    }

    /// Жалоба на сообщение. Причина — одна из значений Android (`SPAM` и т.д.).
    func report(_ message: MessageResponse, reason: String) async {
        do {
            try await services.moderation.report(
                messageUuid: reducer.serverUuid(message.messageUuid),
                reason: reason,
                comment: nil
            )
            state.notice = "Жалоба отправлена"
        } catch {
            state.error = error.localizedDescription
        }
    }

    func block(userUuid: String) async {
        do {
            try await services.moderation.block(userUuid: userUuid, reason: nil)
            state.notice = "Пользователь заблокирован"
        } catch {
            state.error = error.localizedDescription
        }
    }

    /// Точные отметки времени по сообщению для «Деталей».
    func loadMessageStatuses(for message: MessageResponse) async {
        guard message.messageId != nil else { return }
        do {
            state.messageStatuses[message.messageUuid] = try await services.statuses
                .loadMessageStatuses(
                    chatUuid: chatUuid,
                    messageUuid: reducer.serverUuid(message.messageUuid)
                )
        } catch {
            // Время просто не появится — остальные данные «Деталей» остаются.
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
        let targets = selectedMessages.filter {
            $0.messageId != nil && $0.senderUuid != nil && $0.senderUuid == myUserUuid
        }
        guard !targets.isEmpty else {
            state.error = "Можно удалить только свои сообщения"
            exitSelection()
            return
        }
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

    func reportValidationError(_ message: String) {
        state.error = message
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

    private func pendingResponse(_ item: PendingChatMessage) -> MessageResponse {
        MessageResponse(
            messageUuid: item.localUuid,
            messageId: nil,
            chatUuid: item.chatUuid,
            senderId: nil,
            senderUuid: myUserUuid,
            senderName: nil,
            senderAvatar: nil,
            text: item.text,
            messageType: item.messageType ?? "TEXT",
            replyToMessageUuid: item.replyToMessageUuid,
            forwardedFromMessageUuid: nil,
            forwardedFromUserUuid: nil,
            isEdited: false,
            isDeleted: false,
            isPinned: false,
            createdAt: item.createdAt,
            updatedAt: nil,
            reactions: [],
            power: item.power,
            attachments: item.attachments
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

    /// Отмечает прочитанным всё до указанного сообщения. Вызывается, когда
    /// строка реально показана, — как `markReadUpTo` на Android. Watermark
    /// двигается только вперёд, повторные вызовы безопасны.
    func markReadUpTo(_ message: MessageResponse) async {
        guard let messageId = message.messageId,
              messageId > lastMarkedReadMessageId,
              !message.messageUuid.hasPrefix("local-") else { return }
        lastMarkedReadMessageId = messageId
        await services.messages.markMessagesAsRead(
            chatUuid: chatUuid,
            upToMessageUuid: reducer.serverUuid(message.messageUuid)
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
