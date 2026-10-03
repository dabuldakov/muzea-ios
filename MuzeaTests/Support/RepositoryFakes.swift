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
    var sendResult: MessageResponse?
    var loadError: Error?
    var markedRead: [(String, String)] = []

    func loadMessages(chatUuid: String) async throws -> [MessageResponse] {
        if let loadError { throw loadError }
        return messages
    }

    func cachedMessages(chatUuid: String) -> [MessageResponse] { cached }

    func sendMessage(chatUuid: String, text: String) async throws -> MessageResponse {
        sentTexts.append(text)
        return sendResult ?? MessageResponse(
            messageUuid: "server-1",
            chatUuid: chatUuid,
            senderId: nil,
            senderUuid: "me",
            senderName: nil,
            senderAvatar: nil,
            text: text,
            messageType: "TEXT",
            replyToMessageUuid: nil,
            isEdited: false,
            isDeleted: false,
            isPinned: false,
            createdAt: "2026-01-01T00:00:01",
            updatedAt: nil
        )
    }

    func markMessagesAsRead(chatUuid: String, upToMessageUuid: String) async {
        markedRead.append((chatUuid, upToMessageUuid))
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
    var logoutResult = true
    var unread: Int64 = 0

    func deleteAccount() async throws {
        if let deleteError { throw deleteError }
        deleted = true
    }
    func sendHeartbeat() async -> Bool { heartbeatResult }
    func logout() async -> Bool { logoutResult }
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
    var loginError: Error?
    var registerError: Error?
    var loggedIn: [String] = []
    var registered: [String] = []
    var loggedOut = false

    func login(username: String, password: String) async throws -> AuthResponse {
        if let loginError { throw loginError }
        loggedIn.append(username)
        return AuthResponse(token: "t", username: username, role: nil)
    }

    func register(username: String, email: String, password: String, fullName: String) async throws -> AuthResponse {
        if let registerError { throw registerError }
        registered.append(username)
        return AuthResponse(token: "t", username: username, role: nil)
    }

    func logout() { loggedOut = true }
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
