import Foundation
import SwiftUI

/// Ручной DI-контейнер (аналог Hilt-модулей на Android): собирает сетевые
/// клиенты, SRP-репозитории, кэши и use-cases и раздаёт их экранам.
///
/// Зависимости объявлены протоколами, поэтому ViewModel-и легко подменяются в
/// тестах и не знают о конкретных реализациях.
final class AppContainer: ObservableObject {
    let tokenStore: TokenStore
    let consentManager: ConsentManager

    let authRepository: AuthRepositoryProtocol
    let userRepository: UserRepository
    let newsRepository: NewsRepository
    let videoRepository: VideoRepository
    let contentReportRepository: ContentReportRepository
    let cacheManager: CacheManager
    let networkMonitor: NetworkMonitor
    let chatRepository: ChatRepository
    let messageRepository: MessageRepository
    let messageActionsRepository: MessageActionsRepository
    let attachmentRepository: AttachmentRepository
    let gifRepository: GifRepository
    let messageReactionRepository: MessageReactionRepository
    let messageReceiptRepository: MessageReceiptRepository
    let messageStatusRepository: MessageStatusRepository
    let moderationRepository: ModerationRepository
    let chatDraftStore: ChatDraftStore
    let reactionHistoryStore: ReactionHistoryStore
    let chatOutboxStore: ChatOutboxStore
    let pendingAttachmentStore: PendingAttachmentStore
    let chatConversationServices: ChatConversationServices
    let contactRepository: ContactRepository
    let avatarRepository: AvatarRepository
    let chatSessionRepository: ChatSessionRepository
    let openPrivateChat: OpenPrivateChatUseCase

    private let chatListCache: ChatListCache
    private let chatMessagesCache: ChatMessagesCache
    private let privateChatCache: PrivateChatCache
    private let videoListCache: VideoListCache

    /// Держим координатор refresh живым: обработчики 401 ссылаются на него.
    private let tokenRefresher: TokenRefresher

    @Published var isLoggedIn: Bool
    @Published var isConsentAccepted: Bool

    init() {
        let store = TokenStore()
        tokenStore = store
        let consent = ConsentManager()
        consentManager = consent

        let api = API(tokenStore: store)

        let authImpl = AuthRepositoryImpl(client: api.auth, store: store)
        authRepository = authImpl
        userRepository = UserRepositoryImpl(client: api.makeup)
        newsRepository = NewsRepositoryImpl(client: api.makeup)
        contentReportRepository = ContentReportRepositoryImpl(client: api.makeup)

        let cacheDirectories = [
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
            FileManager.default.temporaryDirectory.appendingPathComponent("attachment-cache")
        ].compactMap { $0 }
        cacheManager = CacheManager(
            directories: cacheDirectories,
            clearActions: [{ await GifCache.shared.clearAll() }]
        )
        networkMonitor = NetworkMonitor()

        let videoCache = VideoListCache()
        videoListCache = videoCache
        videoRepository = VideoRepositoryImpl(client: api.makeup, cache: videoCache)

        let chatAuth = ChatAuthManager(client: api.chat, store: store)
        let authorization = ChatAuthorization(client: api.chat, auth: chatAuth)

        ErrorReporter.shared.configure(
            uploader: { [authorization] request in
                do {
                    let _: ErrorReportResponse = try await authorization.authorized {
                        try await authorization.client.request(
                            "POST",
                            "/api/telemetry/errors",
                            body: request
                        )
                    }
                    return true
                } catch {
                    return false
                }
            },
            userIdProvider: { [store] in store.chatUserUuid }
        )
        ErrorReporter.shared.install()
        ErrorReporter.shared.uploadPending()

        let listCache = ChatListCache()
        chatListCache = listCache
        let messagesCache = ChatMessagesCache()
        chatMessagesCache = messagesCache
        let privateCache = PrivateChatCache()
        privateChatCache = privateCache

        let chats = ChatRepositoryImpl(auth: authorization, listCache: listCache, privateCache: privateCache)
        chatRepository = chats
        let messages = MessageRepositoryImpl(auth: authorization, cache: messagesCache)
        messageRepository = messages
        let actions = MessageActionsRepositoryImpl(auth: authorization)
        messageActionsRepository = actions
        let attachments = AttachmentRepositoryImpl(auth: authorization)
        attachmentRepository = attachments
        gifRepository = KlipyGifRepository(auth: authorization)
        let reactions = MessageReactionRepositoryImpl(auth: authorization)
        messageReactionRepository = reactions
        let receipts = MessageReceiptRepositoryImpl(auth: authorization)
        messageReceiptRepository = receipts
        let statuses = MessageStatusRepositoryImpl(auth: authorization)
        messageStatusRepository = statuses
        let moderation = ModerationRepositoryImpl(auth: authorization)
        moderationRepository = moderation
        let drafts = UserDefaultsChatDraftStore()
        chatDraftStore = drafts
        let reactionHistory = UserDefaultsReactionHistoryStore()
        reactionHistoryStore = reactionHistory
        let outbox = FileChatOutboxStore()
        chatOutboxStore = outbox
        let pendingAttachments = FilePendingAttachmentStore()
        pendingAttachmentStore = pendingAttachments
        chatConversationServices = ChatConversationServices(
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
            pendingAttachments: pendingAttachments,
            chats: chats
        )
        contactRepository = ContactRepositoryImpl(auth: authorization)
        avatarRepository = AvatarRepositoryImpl(auth: authorization)
        chatSessionRepository = ChatSessionRepositoryImpl(auth: authorization)
        openPrivateChat = OpenPrivateChatUseCase(repository: chats)

        // Единый refresh-координатор: одноразовый refresh-токен нельзя дёргать
        // параллельно, иначе сервер отзовёт family.
        //
        // Отдельный клиент без `unauthorizedHandler`: сам `/auth/token/refresh`
        // не должен рекурсивно пытаться обновить себя.
        let refreshClient = HTTPClient(baseURL: Config.authBaseURL) { store.token }
        let refresher = TokenRefresher(client: refreshClient, store: store)
        tokenRefresher = refresher
        api.auth.unauthorizedHandler = { [weak refresher] failedToken in
            await refresher?.refresh(failedToken: failedToken) ?? false
        }
        api.makeup.unauthorizedHandler = { [weak refresher] failedToken in
            await refresher?.refresh(failedToken: failedToken) ?? false
        }
        api.chat.unauthorizedHandler = { [weak refresher] failedToken in
            await refresher?.refresh(failedToken: failedToken) ?? false
        }
        // makeup отвечает 403 на отсутствующий/просроченный токен.
        api.makeup.treatsForbiddenAsUnauthorized = true

        isLoggedIn = authImpl.isLoggedIn
        isConsentAccepted = consent.isAccepted

        PushManager.shared.onToken = { token in
            store.fcmToken = token
            store.registeredFcmToken = nil
            Task { await chatAuth.ensureAuthenticated() }
        }
        PushManager.shared.flushIfNeeded()

        Task { [weak self] in
            await refresher.setExpiredHandler { [weak self] in
                Task { @MainActor in
                    self?.clearLocalSession()
                }
            }
        }
    }

    /// UUID текущего пользователя на chat-сервере: `sub` access-токена IdP.
    var myUserUuid: String? {
        JWT.subject(from: tokenStore.token)
    }

    func didLogin() {
        isLoggedIn = true
        ErrorReporter.shared.uploadPending()
    }

    func didAcceptConsent() {
        isConsentAccepted = true
    }

    /// Разлогин: локальные токены чистятся сразу, refresh-сессия отзывается
    /// best-effort. Отдельного chat-логаута больше нет — сервер один.
    func logout() async {
        await authRepository.logout()
        clearCaches()
        isLoggedIn = false
    }

    /// Локальный выход без обращения к серверу. Нужен после удаления аккаунта,
    /// когда серверная сессия уже уничтожена.
    func clearLocalSession() {
        authRepository.clearLocalSession()
        clearCaches()
        isLoggedIn = false
    }

    /// Полная локальная очистка после удаления аккаунта (ст. 14 ФЗ-152):
    /// сессия, кэши, ключи устройства и отзыв согласия.
    func didDeleteAccount() {
        clearLocalSession()
        tokenStore.clearAll()
        consentManager.revoke()
        isConsentAccepted = false
    }

    /// Сброс in-memory кэшей при смене пользователя, чтобы данные прошлого
    /// аккаунта не «протекли» в интерфейс.
    func clearCaches() {
        chatListCache.clear()
        chatMessagesCache.clear()
        privateChatCache.clear()
        videoListCache.clear()
        // Черновики содержат текст прошлого пользователя — после выхода их быть
        // не должно.
        chatDraftStore.clearAll()
        chatOutboxStore.clearAll()
        pendingAttachmentStore.clearAll()
    }
}
