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
    let chatRepository: ChatRepository
    let messageRepository: MessageRepository
    let contactRepository: ContactRepository
    let avatarRepository: AvatarRepository
    let chatSessionRepository: ChatSessionRepository
    let openPrivateChat: OpenPrivateChatUseCase

    private let chatListCache: ChatListCache
    private let chatMessagesCache: ChatMessagesCache
    private let privateChatCache: PrivateChatCache
    private let videoListCache: VideoListCache

    @Published var isLoggedIn: Bool
    @Published var isConsentAccepted: Bool

    init() {
        let store = TokenStore()
        tokenStore = store
        let consent = ConsentManager()
        consentManager = consent

        let api = API(tokenStore: store)

        let authImpl = AuthRepositoryImpl(client: api.makeup, store: store)
        authRepository = authImpl
        userRepository = UserRepositoryImpl(client: api.makeup)
        newsRepository = NewsRepositoryImpl(client: api.makeup)

        let videoCache = VideoListCache()
        videoListCache = videoCache
        videoRepository = VideoRepositoryImpl(client: api.makeup, cache: videoCache)

        let chatAuth = ChatAuthManager(client: api.chat, store: store)
        let authorization = ChatAuthorization(client: api.chat, auth: chatAuth)

        let listCache = ChatListCache()
        chatListCache = listCache
        let messagesCache = ChatMessagesCache()
        chatMessagesCache = messagesCache
        let privateCache = PrivateChatCache()
        privateChatCache = privateCache

        let chats = ChatRepositoryImpl(auth: authorization, listCache: listCache, privateCache: privateCache)
        chatRepository = chats
        messageRepository = MessageRepositoryImpl(auth: authorization, cache: messagesCache)
        contactRepository = ContactRepositoryImpl(auth: authorization)
        avatarRepository = AvatarRepositoryImpl(auth: authorization)
        chatSessionRepository = ChatSessionRepositoryImpl(auth: authorization)
        openPrivateChat = OpenPrivateChatUseCase(repository: chats)

        isLoggedIn = store.isLoggedIn
        isConsentAccepted = consent.isAccepted

        PushManager.shared.onToken = { token in
            store.fcmToken = token
            store.registeredFcmToken = nil
            Task { await chatAuth.ensureAuthenticated() }
        }
        PushManager.shared.flushIfNeeded()
    }

    /// UUID текущего пользователя на chat-сервере, извлечённый из JWT.
    var myUserUuid: String? {
        JWT.subject(from: tokenStore.chatToken)
    }

    func didLogin() {
        isLoggedIn = true
    }

    func didAcceptConsent() {
        isConsentAccepted = true
    }

    /// Разлогин: сначала гасим сессию на чат-сервере, и только затем чистим
    /// локальный токен. Порядок обязателен — запрос несёт access-токен, а после
    /// локальной очистки сервер его уже не проверит, и пользователь продолжит
    /// светиться «в сети» у контактов до истечения TTL.
    func logout() async {
        _ = await chatSessionRepository.logout()
        clearLocalSession()
    }

    /// Локальный выход без обращения к серверу. Нужен после удаления аккаунта,
    /// когда серверная сессия уже уничтожена и логин/регистрация заново создали
    /// бы аккаунт.
    func clearLocalSession() {
        authRepository.logout()
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
    }
}
