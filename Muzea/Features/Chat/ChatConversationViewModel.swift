import Foundation

/// Единое состояние экрана переписки.
struct ChatConversationUiState: Equatable {
    var messages: [ChatMessage] = []
    var isLoading = false
    /// Догрузка истории вверх: true, пока сервер может отдать ещё страницу.
    var hasMoreHistory = true
    var isLoadingMore = false
    var error: String?
    var notice: String?

    /// Сообщение, на которое сейчас отвечаем.
    var replyTo: ChatMessage?
    /// Сообщение, которое сейчас редактируем.
    var editing: ChatMessage?

    var pinned: [ChatMessage] = []
    var receipts: [ChatReceipt] = []
    var receiptsLoaded = false
    /// Точные статусы по сообщению, загруженные при открытии «Деталей».
    var messageStatuses: [String: [MessageStatus]] = [:]
    /// Статусы собственных сообщений: uuid -> галочка.
    var statuses: [String: MessageDeliveryStatus] = [:]
    var failedMessages: Set<String> = []

    var selection: Set<String> = []
    var participants: [ChatParticipant] = []
    var forwardChats: [Chat] = []
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
    private var retryingAttachments = false
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

        let storedAttachments = services.pendingAttachments.load(chatUuid: chatUuid)
        state.pendingAttachments = storedAttachments.map {
            PendingChatAttachment(
                id: $0.id,
                fileName: $0.fileName,
                kind: AttachmentKind(rawValue: $0.kind) ?? .document,
                uploaded: $0.uploaded
            )
        }
        state.isUploadingAttachments = state.pendingAttachments.contains { !$0.isUploaded }
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
        await retryPendingAttachments()
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

    /// Догружает страницу сообщений старше самого раннего серверного.
    /// Ошибки не показываем поверх переписки: пользователь просто увидит,
    /// что история не добавилась, и сможет потянуть ещё раз.
    func loadOlderMessages() async {
        guard state.hasMoreHistory, !state.isLoadingMore else { return }
        guard let oldest = state.messages.first(where: {
            !$0.messageUuid.hasPrefix("local-")
        }) else { return }

        state.isLoadingMore = true
        defer { state.isLoadingMore = false }
        do {
            let older = try await services.messages.loadMessagesBefore(
                chatUuid: chatUuid,
                beforeMessageUuid: oldest.messageUuid,
                limit: Config.messagePageSize
            )
            let known = Set(state.messages.map(\.messageUuid))
            let fresh = older.filter { !known.contains($0.messageUuid) }
            // Сервер вернул только уже известные сообщения — дальше страниц нет.
            if older.count < Config.messagePageSize || fresh.isEmpty {
                state.hasMoreHistory = false
            }
            if !fresh.isEmpty {
                merge(fresh)
            }
        } catch {
            // Сеть вернётся — догрузим при следующем появлении сентинела.
        }
    }

    /// Разовая полная загрузка вне цикла опроса (pull-to-refresh, возврат).
    func refresh() async {
        await loadFull()
    }

    @discardableResult
    func send(_ text: String, power: Int = 0) async -> Bool {
        await send(text, power: power, forcedMessageType: nil)
    }

    @discardableResult
    private func send(
        _ text: String,
        power: Int,
        forcedMessageType: String?
    ) async -> Bool {
        if let editing = state.editing {
            return await submitEdit(editing, text: text)
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let uploaded = state.pendingAttachments.compactMap(\.uploaded)
        guard !trimmed.isEmpty || !uploaded.isEmpty else { return false }
        guard state.pendingAttachments.allSatisfy(\.isUploaded) else {
            state.error = L10n.errorAttachmentUpload
            return false
        }
        let kinds = state.pendingAttachments.map(\.kind)
        let messageType = forcedMessageType ?? AttachmentPolicy.messageType(for: kinds)
        let attachmentUuids = uploaded.compactMap(\.attachmentUuid)
        let clampedPower = min(max(power, 0), 100)

        let replyToUuid = state.replyTo.map { reducer.serverUuid($0.messageUuid) }
        let clientMessageId = UUID().uuidString
        let optimistic = ChatMessage(
            messageUuid: "local-\(UUID().uuidString)",
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
            services.pendingAttachments.clear(chatUuid: chatUuid)
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
            services.pendingAttachments.clear(chatUuid: chatUuid)
            state.failedMessages.insert(optimistic.messageUuid)
            state.error = error.localizedDescription
            recomputeStatuses()
            return false
        }
    }

    /// Ручной повтор неудачной отправки.
    func retry(_ message: ChatMessage) async {
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

    func beginReply(to message: ChatMessage) {
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

    func addVideo(
        data: Data,
        fileName: String,
        width: Int? = nil,
        height: Int? = nil,
        duration: Int? = nil,
        thumbnail: Data? = nil
    ) async {
        let rule = AttachmentPolicy.rule(for: fileName)
        await upload(
            data: data,
            fileName: fileName,
            mimeType: rule?.mimeType ?? "video/mp4",
            kind: .video,
            thumbnail: thumbnail,
            width: width,
            height: height,
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
        let before = state.pendingAttachments.count
        await addAudio(
            data: recorded.data,
            fileName: recorded.url.lastPathComponent,
            duration: recorded.duration
        )
        // Временный файл записи больше не нужен: данные уже в очереди/на сервере.
        try? FileManager.default.removeItem(at: recorded.url)
        // Именно новое вложение должно быть загружено, а не любое из старых.
        guard state.pendingAttachments.count == before + 1,
              state.pendingAttachments.last?.isUploaded == true else { return false }
        return await send("")
    }

    @discardableResult
    func sendVideoNote(_ recorded: RecordedVideoNote) async -> Bool {
        let before = state.pendingAttachments.count
        await upload(
            data: recorded.data,
            fileName: recorded.fileName,
            mimeType: "video/mp4",
            kind: .video,
            thumbnail: recorded.thumbnail,
            width: recorded.width,
            height: recorded.height,
            duration: recorded.duration
        )
        try? FileManager.default.removeItem(at: recorded.url)
        guard state.pendingAttachments.count == before + 1,
              state.pendingAttachments.last?.isUploaded == true else { return false }
        return await send("", power: 0, forcedMessageType: "VIDEO_NOTE")
    }

    func sendGif(_ gif: Gif) async {
        let replyToUuid = state.replyTo.map { reducer.serverUuid($0.messageUuid) }
        let attachment = ChatAttachment(
            attachmentUuid: nil,
            fileName: gif.title,
            fileUrl: gif.url,
            thumbnailUrl: gif.previewUrl,
            mp4Url: gif.mp4Url,
            fileSize: nil,
            mimeType: "image/gif",
            type: "GIF",
            width: gif.width,
            height: gif.height,
            duration: nil,
            gifKey: gif.gifKey
        )
        let optimistic = ChatMessage(
            messageUuid: "local-\(UUID().uuidString)",
            chatUuid: chatUuid,
            senderId: nil,
            senderUuid: myUserUuid,
            senderName: nil,
            senderAvatar: nil,
            text: nil,
            messageType: "GIF",
            replyToMessageUuid: replyToUuid,
            isEdited: false,
            isDeleted: false,
            isPinned: false,
            createdAt: Self.pendingDateFormatter.string(from: Date()),
            updatedAt: nil,
            reactions: [],
            attachments: [attachment]
        )
        merge([optimistic])
        state.replyTo = nil

        do {
            let sent = try await services.messages.sendGif(
                chatUuid: chatUuid,
                gif: gif,
                replyToMessageUuid: replyToUuid
            )
            state.messages = reducer.applyServerEcho(
                current: state.messages,
                localUuid: optimistic.messageUuid,
                serverMessage: sent
            )
            recomputeStatuses()
            await markDelivered()
        } catch {
            state.messages = reducer.removeMessage(
                current: state.messages,
                messageUuid: optimistic.messageUuid
            )
            state.error = error.localizedDescription
            ErrorReporter.logCaught("ChatSend", error)
            recomputeStatuses()
        }
    }

    func removePendingAttachment(_ id: String) {
        services.pendingAttachments.remove(id: id)
        state.pendingAttachments.removeAll { $0.id == id }
        state.isUploadingAttachments = state.pendingAttachments.contains { $0.isUploading }
    }

    /// Повторная загрузка одного файла — по тапу на ошибку, как на Android.
    func retryPendingAttachment(_ id: String) async {
        guard let record = services.pendingAttachments.load(chatUuid: chatUuid)
            .first(where: { $0.id == id }), record.uploaded == nil else { return }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: record.filePath)) else {
            removePendingAttachment(id)
            return
        }
        let thumbnail = record.thumbnailPath.flatMap { path in
            try? Data(contentsOf: URL(fileURLWithPath: path))
        }
        if let index = state.pendingAttachments.firstIndex(where: { $0.id == id }) {
            state.pendingAttachments[index].error = nil
            state.pendingAttachments[index].progress = 0
        }
        state.isUploadingAttachments = true
        await performUpload(id: id, record: record, data: data, thumbnail: thumbnail)
        state.isUploadingAttachments = state.pendingAttachments.contains { $0.isUploading }
    }

    /// Догружает вложения, которые были выбраны до перезапуска приложения.
    func retryPendingAttachments() async {
        guard !retryingAttachments else { return }
        let stored = services.pendingAttachments.load(chatUuid: chatUuid)
            .filter { $0.uploaded == nil }
        guard !stored.isEmpty else { return }
        retryingAttachments = true
        defer { retryingAttachments = false }
        state.isUploadingAttachments = true

        for item in stored {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: item.filePath)) else {
                removePendingAttachment(item.id)
                continue
            }
            let thumbnail = item.thumbnailPath.flatMap { path in
                try? Data(contentsOf: URL(fileURLWithPath: path))
            }
            await performUpload(id: item.id, record: item, data: data, thumbnail: thumbnail)
        }
        state.isUploadingAttachments = state.pendingAttachments.contains { $0.isUploading }
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
            state.error = L10n.attachmentLimit(AttachmentPolicy.maxAttachmentsPerMessage)
            return
        }
        if let message = AttachmentPolicy.validationError(
            fileName: fileName,
            size: Int64(data.count)
        ) {
            state.error = message
            return
        }

        let id = UUID().uuidString
        let pending = PendingChatAttachment(
            id: id,
            fileName: fileName,
            kind: kind,
            uploaded: nil
        )
        state.pendingAttachments.append(pending)
        state.isUploadingAttachments = true

        let record = StoredPendingAttachment(
            id: id,
            chatUuid: chatUuid,
            fileName: fileName,
            mimeType: mimeType,
            kind: kind.rawValue,
            width: width,
            height: height,
            duration: duration,
            filePath: "",
            thumbnailPath: nil,
            uploaded: nil
        )
        try? services.pendingAttachments.save(
            record: record,
            data: data,
            thumbnail: thumbnail
        )
        let stored = services.pendingAttachments.load(chatUuid: chatUuid)
            .first { $0.id == id } ?? record

        await performUpload(id: id, record: stored, data: data, thumbnail: thumbnail)
        state.isUploadingAttachments = state.pendingAttachments.contains { $0.isUploading }
    }

    /// Одна загрузка: прогресс обновляет только свой файл, ошибка тоже локальна.
    private func performUpload(
        id: String,
        record: StoredPendingAttachment,
        data: Data,
        thumbnail: Data?
    ) async {
        let request = AttachmentUploadRequest(
            chatUuid: chatUuid,
            data: data,
            fileName: record.fileName,
            mimeType: record.mimeType,
            kind: AttachmentKind(rawValue: record.kind) ?? .document,
            thumbnail: thumbnail,
            width: record.width,
            height: record.height,
            duration: record.duration,
            onProgress: { [weak self] progress in
                Task { @MainActor in
                    self?.updateUploadProgress(id: id, progress: progress)
                }
            }
        )

        do {
            let uploaded = try await services.attachments.upload(request)
            var stored = record
            stored.uploaded = uploaded
            services.pendingAttachments.update(stored)
            if let index = state.pendingAttachments.firstIndex(where: { $0.id == id }) {
                state.pendingAttachments[index].uploaded = uploaded
                state.pendingAttachments[index].error = nil
                state.pendingAttachments[index].progress = 1
            }
        } catch {
            ErrorReporter.logCaught("ChatUpload", error)
            // Файл остаётся в дисковой очереди: повтор — тапом по вложению.
            let message = error.localizedDescription
            if let index = state.pendingAttachments.firstIndex(where: { $0.id == id }) {
                state.pendingAttachments[index].error = message
            } else {
                state.error = message
            }
        }
    }

    /// Обновление прогресса одного файла. Внутренний, чтобы тесты могли
    /// проверить адресность и зажим значений без реального URLSession.
    func updateUploadProgress(id: String, progress: Double) {
        guard let index = state.pendingAttachments.firstIndex(where: { $0.id == id }) else {
            return
        }
        state.pendingAttachments[index].progress = progress
    }

    func beginEdit(_ message: ChatMessage) {
        state.editing = message
        state.replyTo = nil
    }

    func cancelComposer() {
        state.replyTo = nil
        state.editing = nil
    }

    func deleteMessage(_ message: ChatMessage) async {
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

    func togglePin(_ message: ChatMessage) async {
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

    func toggleReaction(_ message: ChatMessage, emoji: String) async {
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
    func report(_ message: ChatMessage, reason: String) async {
        do {
            try await services.moderation.report(
                messageUuid: reducer.serverUuid(message.messageUuid),
                reason: reason,
                comment: nil
            )
            state.notice = L10n.noticeReported
        } catch {
            state.error = error.localizedDescription
        }
    }

    func block(userUuid: String) async {
        do {
            try await services.moderation.block(userUuid: userUuid, reason: nil)
            state.notice = L10n.noticeBlocked
        } catch {
            state.error = error.localizedDescription
        }
    }

    /// Точные отметки времени по сообщению для «Деталей».
    func loadMessageStatuses(for message: ChatMessage) async {
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
        _ message: ChatMessage,
        toChatUuid target: String,
        comment: String? = nil
    ) async {
        await forward(messages: [message], toChatUuid: target, comment: comment)
    }

    /// Пересылка пачки: комментарий уходит один раз после всех сообщений.
    func forward(
        messages: [ChatMessage],
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
        state.notice = L10n.forwarded
        exitSelection()
    }

    // MARK: - Selection

    func enterSelection(with message: ChatMessage) {
        state.selection = [message.messageUuid]
    }

    func toggleSelection(_ message: ChatMessage) {
        if state.selection.contains(message.messageUuid) {
            state.selection.remove(message.messageUuid)
        } else {
            state.selection.insert(message.messageUuid)
        }
    }

    func exitSelection() {
        state.selection = []
    }

    var selectedMessages: [ChatMessage] {
        state.messages.filter { state.selection.contains($0.messageUuid) }
    }

    func deleteSelected() async {
        let targets = selectedMessages.filter {
            $0.messageId != nil && $0.senderUuid != nil && $0.senderUuid == myUserUuid
        }
        guard !targets.isEmpty else {
            state.error = L10n.errorOnlyOwnDelete
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
            ErrorReporter.logCaught("ChatRefresh", error)
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

    private func submitEdit(_ target: ChatMessage, text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state.error = L10n.errorEmptyMessage
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

    private func merge(_ incoming: [ChatMessage]) {
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

    private func pendingResponse(_ item: PendingChatMessage) -> ChatMessage {
        ChatMessage(
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
    func markReadUpTo(_ message: ChatMessage) async {
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
