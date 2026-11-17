import Foundation
@testable import Muzea

/// Ручные тест-дубли протоколов репозиториев: позволяют проверять ViewModel и
/// use-cases без сети. Аналог MockK-моков на Android.

final class FakeChatRepository: ChatRepository {
    var chats: [ChatResponse] = []
    var cached: [ChatResponse] = []
    var participants: [String: [ChatParticipantResponse]] = [:]
    var privateChats: [String: ChatResponse] = [:]
    var createdPrivateChats: [String] = []
    var createdGroups: [(String, [String])] = []
    var addedParticipants: [(String, [String])] = []
    var loadChatsError: Error?

    func loadChats() async throws -> [ChatResponse] {
        if let loadChatsError { throw loadChatsError }
        return chats
    }

    func cachedChats() -> [ChatResponse] { cached }

    func loadChatParticipants(chatUuid: String) async throws -> [ChatParticipantResponse] {
        participants[chatUuid] ?? []
    }

    func createPrivateChat(userUuid: String) async throws -> ChatResponse {
        createdPrivateChats.append(userUuid)
        return ChatResponse(
            chatUuid: "created-\(userUuid)",
            chatType: "PRIVATE",
            title: nil,
            avatarUrl: nil,
            createdAt: nil,
            updatedAt: nil,
            participantCount: 2,
            lastMessage: nil,
            unreadCount: 0
        )
    }

    func findPrivateChatWith(userUuid: String) async throws -> ChatResponse? {
        privateChats[userUuid]
    }

    func createGroupChat(title: String, memberUuids: [String]) async throws -> ChatResponse {
        createdGroups.append((title, memberUuids))
        return ChatResponse(
            chatUuid: "group-1",
            chatType: "GROUP",
            title: title,
            avatarUrl: nil,
            createdAt: nil,
            updatedAt: nil,
            participantCount: Int64(memberUuids.count),
            lastMessage: nil,
            unreadCount: 0
        )
    }

    func addGroupParticipants(chatUuid: String, memberUuids: [String]) async throws {
        addedParticipants.append((chatUuid, memberUuids))
    }
}

final class FakeMessageRepository: MessageRepository {
    var messages: [MessageResponse] = []
    var cached: [MessageResponse] = []
    var sentTexts: [String] = []
    var sentRequests: [(text: String, replyTo: String?, clientId: String?, power: Int)] = []
    var sentMedia: [(messageType: String, attachments: [String])] = []
    var sendResult: MessageResponse?
    var sendError: Error?
    var loadError: Error?
    var markedRead: [(String, String)] = []
    var markedDelivered: [(String, String)] = []

    func loadMessages(chatUuid: String) async throws -> [MessageResponse] {
        if let loadError { throw loadError }
        return messages
    }

    func cachedMessages(chatUuid: String) -> [MessageResponse] { cached }

    func sendMessage(chatUuid: String, text: String) async throws -> MessageResponse {
        try await sendMessage(
            chatUuid: chatUuid,
            text: text,
            replyToMessageUuid: nil,
            clientMessageId: nil,
            power: 0
        )
    }

    func sendMessage(
        chatUuid: String,
        text: String,
        replyToMessageUuid: String?,
        clientMessageId: String?,
        power: Int
    ) async throws -> MessageResponse {
        try await sendMessage(
            chatUuid: chatUuid,
            text: text,
            messageType: "TEXT",
            replyToMessageUuid: replyToMessageUuid,
            clientMessageId: clientMessageId,
            attachments: [],
            power: power
        )
    }

    func sendMessage(
        chatUuid: String,
        text: String,
        messageType: String,
        replyToMessageUuid: String?,
        clientMessageId: String?,
        attachments: [String],
        power: Int
    ) async throws -> MessageResponse {
        sentTexts.append(text)
        sentRequests.append((text, replyToMessageUuid, clientMessageId, power))
        sentMedia.append((messageType, attachments))
        if let sendError { throw sendError }
        return sendResult ?? MessageResponse(
            messageUuid: "server-1",
            chatUuid: chatUuid,
            senderId: nil,
            senderUuid: "me",
            senderName: nil,
            senderAvatar: nil,
            text: text,
            messageType: messageType,
            replyToMessageUuid: replyToMessageUuid,
            isEdited: false,
            isDeleted: false,
            isPinned: false,
            createdAt: "2026-01-01T00:00:01",
            updatedAt: nil,
            power: power
        )
    }

    func markMessagesAsRead(chatUuid: String, upToMessageUuid: String) async {
        markedRead.append((chatUuid, upToMessageUuid))
    }

    func markMessagesAsDelivered(chatUuid: String, upToMessageUuid: String) async {
        markedDelivered.append((chatUuid, upToMessageUuid))
    }
}

final class FakeAttachmentRepository: AttachmentRepository {
    var uploads: [(String, String, AttachmentKind)] = []
    var response: AttachmentResponse?
    var downloadData = Data([1, 2, 3])
    var downloads = 0

    func upload(
        chatUuid: String,
        data: Data,
        fileName: String,
        mimeType: String,
        kind: AttachmentKind,
        thumbnail: Data?,
        width: Int?,
        height: Int?,
        duration: Int?
    ) async throws -> AttachmentResponse {
        uploads.append((chatUuid, fileName, kind))
        let result = response ?? AttachmentResponse(
            attachmentUuid: "a-1",
            fileName: fileName,
            fileUrl: "stored-key",
            thumbnailUrl: nil,
            mp4Url: nil,
            fileSize: Int64(data.count),
            mimeType: mimeType,
            type: kind.rawValue,
            width: width,
            height: height,
            duration: duration,
            gifKey: nil
        )
        response = result
        return result
    }

    func download(attachmentUuid: String) async throws -> Data {
        downloads += 1
        return downloadData
    }

    func preview(attachmentUuid: String) async throws -> Data {
        downloadData
    }
}

final class FakeMessageActionsRepository: MessageActionsRepository {    var edited: [(String, String)] = []
    var deleted: [String] = []
    var forwarded: [(String, String)] = []
    var pinned: [(String, String)] = []
    var unpinned: [(String, String)] = []
    var pinnedMessages: [MessageResponse] = []
    var editResult: MessageResponse?

    func editMessage(messageUuid: String, text: String) async throws -> MessageResponse {
        edited.append((messageUuid, text))
        guard let editResult else { throw APIError.server(500, "no edit result") }
        return editResult
    }

    func deleteMessage(messageUuid: String) async throws {
        deleted.append(messageUuid)
    }

    func forwardMessage(messageUuid: String, toChatUuid: String) async throws -> MessageResponse {
        forwarded.append((messageUuid, toChatUuid))
        return TestData.message("forwarded-\(messageUuid)")
    }

    func pinMessage(chatUuid: String, messageUuid: String) async throws {
        pinned.append((chatUuid, messageUuid))
    }

    func unpinMessage(chatUuid: String, messageUuid: String) async throws {
        unpinned.append((chatUuid, messageUuid))
    }

    func loadPinned(chatUuid: String) async throws -> [MessageResponse] {
        pinnedMessages
    }
}

final class FakeMessageReactionRepository: MessageReactionRepository {
    var reactions: [String: [MessageReactionResponse]] = [:]
    var toggles: [(String, String)] = []

    func toggleReaction(messageUuid: String, emoji: String) async throws -> [MessageReactionResponse] {
        toggles.append((messageUuid, emoji))
        return reactions[messageUuid] ?? []
    }
}

final class FakeMessageReceiptRepository: MessageReceiptRepository {
    var receipts: [ChatReceiptResponse] = []
    var loads = 0

    func loadReceipts(chatUuid: String) async throws -> [ChatReceiptResponse] {
        loads += 1
        return receipts
    }
}

final class FakeMessageStatusRepository: MessageStatusRepository {
    var statuses: [String: [MessageStatusResponse]] = [:]
    var loads: [(String, String)] = []

    func loadMessageStatuses(
        chatUuid: String,
        messageUuid: String
    ) async throws -> [MessageStatusResponse] {
        loads.append((chatUuid, messageUuid))
        return statuses[messageUuid] ?? []
    }
}

final class FakeModerationRepository: ModerationRepository {
    var reports: [(String, String, String?)] = []
    var blocks: [(String, String?)] = []

    func report(messageUuid: String, reason: String, comment: String?) async throws {
        reports.append((messageUuid, reason, comment))
    }

    func block(userUuid: String, reason: String?) async throws {
        blocks.append((userUuid, reason))
    }
}

final class FakeReactionHistoryStore: ReactionHistoryStore {
    var emojis: [String] = []

    func recent() -> [String] {
        emojis.isEmpty ? Array(ReactionCatalog.all.prefix(ReactionCatalog.recentLimit)) : emojis
    }

    func record(_ emoji: String) {
        emojis = [emoji] + emojis.filter { $0 != emoji }
    }
}

final class FakeChatOutboxStore: ChatOutboxStore {
    var items: [PendingChatMessage] = []

    func pending(chatUuid: String) -> [PendingChatMessage] {
        items.filter { $0.chatUuid == chatUuid }
    }

    func save(_ message: PendingChatMessage) {
        items.removeAll { $0.clientMessageId == message.clientMessageId }
        items.append(message)
    }

    func remove(clientMessageId: String) {
        items.removeAll { $0.clientMessageId == clientMessageId }
    }

    func clearAll() {
        items.removeAll()
    }
}

final class FakeChatDraftStore: ChatDraftStore {
    var storage: [String: String] = [:]

    func draft(chatUuid: String) -> String? { storage[chatUuid] }

    func save(chatUuid: String, text: String?) {
        if let text, !text.isEmpty {
            storage[chatUuid] = text
        } else {
            storage.removeValue(forKey: chatUuid)
        }
    }

    func clear(chatUuid: String) { storage.removeValue(forKey: chatUuid) }

    func clearAll() { storage.removeAll() }
}

extension ChatConversationServices {
    static func fake(
        messages: FakeMessageRepository = FakeMessageRepository(),
        actions: FakeMessageActionsRepository = FakeMessageActionsRepository(),
        attachments: FakeAttachmentRepository = FakeAttachmentRepository(),
        reactions: FakeMessageReactionRepository = FakeMessageReactionRepository(),
        receipts: FakeMessageReceiptRepository = FakeMessageReceiptRepository(),
        statuses: FakeMessageStatusRepository = FakeMessageStatusRepository(),
        moderation: FakeModerationRepository = FakeModerationRepository(),
        drafts: FakeChatDraftStore = FakeChatDraftStore(),
        reactionHistory: FakeReactionHistoryStore = FakeReactionHistoryStore(),
        outbox: FakeChatOutboxStore = FakeChatOutboxStore(),
        chats: FakeChatRepository = FakeChatRepository()
    ) -> ChatConversationServices {
        ChatConversationServices(
            messages: messages,
            actions: actions,
            attachments: attachments,
            reactions: reactions,
            receipts: receipts,
            statuses: statuses,
            moderation: moderation,
            drafts: drafts,
            reactionHistory: reactionHistory,
            outbox: outbox,
            chats: chats
        )
    }
}

final class FakeContactRepository: ContactRepository {
    var contacts: [ContactResponse] = []
    var added: [String] = []
    var presence: [String: PresenceResponse] = [:]
    var loadError: Error?

    func loadContacts() async throws -> [ContactResponse] {
        if let loadError { throw loadError }
        return contacts
    }

    func addContact(username: String) async throws -> ContactResponse {
        added.append(username)
        return ContactResponse(
            contactUuid: "k-\(username)",
            contactUserId: nil,
            contactUserUuid: "u-\(username)",
            username: username,
            firstName: nil,
            lastName: nil,
            fullName: nil,
            avatarUrl: nil,
            contactName: nil,
            isOnline: false,
            lastSeenAt: nil,
            addedAt: nil
        )
    }

    func loadPresence(userUuids: [String]) async -> [String: PresenceResponse] { presence }
}

final class FakeAvatarRepository: AvatarRepository {
    var avatar: String?
    var uploadedAvatar: String?
    var chatAvatar: String?
    var deleted = false

    func loadAvatar() async throws -> String? { avatar }
    func uploadAvatar(data: Data, fileName: String, mimeType: String) async throws -> String? { uploadedAvatar }
    func deleteAvatar() async throws { deleted = true }
    func uploadChatAvatar(chatUuid: String, data: Data, fileName: String, mimeType: String) async throws -> String? {
        chatAvatar
    }
}

final class FakeChatSessionRepository: ChatSessionRepository {
    var deleteError: Error?
    var deleted = false
    var heartbeatResult = true
    var unread: Int64 = 0

    func deleteAccount() async throws {
        if let deleteError { throw deleteError }
        deleted = true
    }
    func sendHeartbeat() async -> Bool { heartbeatResult }
    func totalUnreadCount() async throws -> Int64 { unread }
}

final class FakeUserRepository: UserRepository {
    var user: UserResponse?
    var deletedIds: [Int64] = []
    var deleteError: Error?

    func currentUser() async throws -> UserResponse {
        guard let user else { throw APIError.server(500, "no user") }
        return user
    }
    func updateUser(id: Int64, fullName: String, email: String) async throws -> UserResponse {
        guard let user else { throw APIError.server(500, "no user") }
        return user
    }
    func deleteAccount(id: Int64) async throws {
        if let deleteError { throw deleteError }
        deletedIds.append(id)
    }
}

final class FakeNewsRepository: NewsRepository {
    var pages: [PageResponse<NewsResponse>] = []
    var byId: [Int64: NewsResponse] = [:]
    var deleted: [Int64] = []

    func getNews(page: Int, size: Int) async throws -> PageResponse<NewsResponse> {
        page < pages.count ? pages[page] : PageResponse(content: [], empty: true, first: false, last: true, number: page, numberOfElements: 0, size: size, totalElements: 0, totalPages: 0)
    }
    func getNewsById(_ id: Int64) async throws -> NewsResponse {
        guard let item = byId[id] else { throw APIError.server(404, "not found") }
        return item
    }
    func createNews(title: String, content: String, videoId: Int64?, image: UploadFile?) async throws -> NewsCreateResponse {
        NewsCreateResponse(id: 1)
    }
    func deleteNews(_ id: Int64) async throws { deleted.append(id) }
}

final class FakeVideoRepository: VideoRepository {
    var videos: [VideoResponse] = []
    var cached: [VideoResponse] = []
    var deleted: [Int64] = []

    func getVideos() async throws -> [VideoResponse] { videos }
    func cachedVideos() -> [VideoResponse] { cached }
    func getVideoById(_ id: Int64) async throws -> VideoResponse {
        guard let video = videos.first(where: { $0.id == id }) else { throw APIError.server(404, "not found") }
        return video
    }
    func uploadVideo(title: String, description: String?, data: Data, fileName: String, mimeType: String, thumbnail: UploadFile?) async throws -> VideoResponse {
        videos.first ?? VideoResponse(id: 1, title: title, description: description, url: "", thumbnailUrl: nil, fileSize: nil, durationSeconds: nil, views: 0, likes: nil, likedByMe: nil, uploadedBy: "me", uploadedAt: "")
    }
    func deleteVideo(_ id: Int64) async throws { deleted.append(id) }
}

final class FakeAuthRepository: AuthRepositoryProtocol {
    var isLoggedIn = false
    var registerError: Error?
    var verifyEmailError: Error?
    var resendError: Error?
    var requestCodeError: Error?
    var verifyLoginError: Error?
    var currentUserError: Error?
    var deleteError: Error?
    var currentUserResult = AuthServiceUser(
        id: "u-1",
        email: "alice@example.com",
        username: "alice",
        displayName: "Alice",
        emailVerified: true
    )

    var registered: [(email: String, username: String, displayName: String?)] = []
    var verifiedEmails: [(email: String, code: String)] = []
    var resent: [String] = []
    var requestedCodes: [String] = []
    var verifiedLogins: [(email: String, code: String)] = []
    var deleted = false
    var loggedOut = false
    var cleared = false

    func register(email: String, username: String, displayName: String?) async throws {
        if let registerError { throw registerError }
        registered.append((email, username, displayName))
    }

    func verifyEmail(email: String, code: String) async throws {
        if let verifyEmailError { throw verifyEmailError }
        verifiedEmails.append((email, code))
        isLoggedIn = true
    }

    func resendVerification(email: String) async throws {
        if let resendError { throw resendError }
        resent.append(email)
    }

    func requestLoginCode(email: String) async throws {
        if let requestCodeError { throw requestCodeError }
        requestedCodes.append(email)
    }

    func verifyLoginCode(email: String, code: String) async throws {
        if let verifyLoginError { throw verifyLoginError }
        verifiedLogins.append((email, code))
        isLoggedIn = true
    }

    func currentUser() async throws -> AuthServiceUser {
        if let currentUserError { throw currentUserError }
        return currentUserResult
    }

    func deleteAccount() async throws {
        if let deleteError { throw deleteError }
        deleted = true
    }

    func logout() async {
        isLoggedIn = false
        loggedOut = true
    }

    func clearLocalSession() {
        isLoggedIn = false
        cleared = true
    }
}

// MARK: - Builders

enum TestData {
    static func chat(_ uuid: String, type: String = "PRIVATE", title: String? = nil, unread: Int64 = 0) -> ChatResponse {
        ChatResponse(
            chatUuid: uuid,
            chatType: type,
            title: title,
            avatarUrl: nil,
            createdAt: nil,
            updatedAt: nil,
            participantCount: nil,
            lastMessage: nil,
            unreadCount: unread
        )
    }

    static func message(_ uuid: String, text: String = "t", createdAt: String? = "2026-01-01T00:00:00", sender: String? = "me") -> MessageResponse {
        MessageResponse(
            messageUuid: uuid,
            chatUuid: "c-1",
            senderId: nil,
            senderUuid: sender,
            senderName: nil,
            senderAvatar: nil,
            text: text,
            messageType: "TEXT",
            replyToMessageUuid: nil,
            isEdited: false,
            isDeleted: false,
            isPinned: false,
            createdAt: createdAt,
            updatedAt: nil
        )
    }

    static func contact(_ uuid: String, online: Bool = false) -> ContactResponse {
        ContactResponse(
            contactUuid: "k-\(uuid)",
            contactUserId: nil,
            contactUserUuid: uuid,
            username: uuid,
            firstName: nil,
            lastName: nil,
            fullName: nil,
            avatarUrl: nil,
            contactName: nil,
            isOnline: online,
            lastSeenAt: nil,
            addedAt: nil
        )
    }
}
