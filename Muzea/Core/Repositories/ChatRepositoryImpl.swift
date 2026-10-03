import Foundation

/// Реализация `ChatRepository`: диалоги, приватные/групповые чаты и участники.
final class ChatRepositoryImpl: ChatRepository {
    private static let privateChatType = "PRIVATE"

    private let auth: ChatAuthorization
    private let listCache: ChatListCache
    private let privateCache: PrivateChatCache

    init(auth: ChatAuthorization, listCache: ChatListCache, privateCache: PrivateChatCache) {
        self.auth = auth
        self.listCache = listCache
        self.privateCache = privateCache
    }

    func loadChats() async throws -> [ChatResponse] {
        let chats: [ChatResponse] = try await auth.authorized {
            try await auth.client.request("GET", "/api/chats")
        }
        listCache.put(chats)
        return chats
    }

    func cachedChats() -> [ChatResponse] {
        listCache.get()
    }

    func loadChatParticipants(chatUuid: String) async throws -> [ChatParticipantResponse] {
        try await auth.authorized {
            try await auth.client.request("GET", "/api/chats/\(chatUuid)/participants")
        }
    }

    func createPrivateChat(userUuid: String) async throws -> ChatResponse {
        let chat: ChatResponse = try await auth.authorized {
            try await auth.client.request(
                "POST",
                "/api/chats/private",
                body: CreatePrivateChatRequest(otherUserUuid: userUuid)
            )
        }
        privateCache.put(userUuid: userUuid, chat: chat)
        return chat
    }

    /// Ищет уже существующий приватный чат с пользователем.
    ///
    /// У приватных чатов нет названия, поэтому сопоставляем по участникам:
    /// перебираем приватные чаты и смотрим, есть ли среди участников нужный
    /// userUuid. Заодно заполняем кэш по всем найденным парам, чтобы следующие
    /// тапы были мгновенными. Нужен, чтобы повторное нажатие на контакт открывало
    /// существующую переписку, а не создавало дубликат.
    func findPrivateChatWith(userUuid: String) async throws -> ChatResponse? {
        if let cached = privateCache.get(userUuid: userUuid) {
            return cached
        }

        let chats = try await loadChats()
        var match: ChatResponse?
        for chat in chats where chat.chatType?.caseInsensitiveCompare(Self.privateChatType) == .orderedSame {
            let participants = (try? await loadChatParticipants(chatUuid: chat.chatUuid)) ?? []
            for participant in participants {
                guard let uuid = participant.userUuid, !uuid.isEmpty else { continue }
                privateCache.put(userUuid: uuid, chat: chat)
            }
            if match == nil, participants.contains(where: { $0.userUuid == userUuid }) {
                match = chat
            }
        }
        return match
    }

    func createGroupChat(title: String, memberUuids: [String]) async throws -> ChatResponse {
        try await auth.authorized {
            try await auth.client.request(
                "POST",
                "/api/chats/group",
                body: CreateGroupChatRequest(title: title, memberUuids: memberUuids)
            )
        }
    }

    func addGroupParticipants(chatUuid: String, memberUuids: [String]) async throws {
        try await auth.authorized {
            try await auth.client.requestVoid(
                "POST",
                "/api/chats/\(chatUuid)/participants",
                body: AddGroupParticipantsRequest(memberUuids: memberUuids)
            )
        }
    }
}
