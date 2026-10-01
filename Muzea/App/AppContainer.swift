import Foundation
import SwiftUI

final class AppContainer: ObservableObject {
    let tokenStore: TokenStore
    let consentManager: ConsentManager
    let authRepository: AuthRepository
    let newsRepository: NewsRepository
    let videoRepository: VideoRepository
    let chatAuthManager: ChatAuthManager
    let chatRepository: ChatRepository

    @Published var isLoggedIn: Bool
    @Published var isConsentAccepted: Bool

    init() {
        let store = TokenStore()
        tokenStore = store
        let consent = ConsentManager()
        consentManager = consent

        let api = API(tokenStore: store)
        authRepository = AuthRepository(client: api.makeup, store: store)
        newsRepository = NewsRepository(client: api.makeup)
        videoRepository = VideoRepository(client: api.makeup)

        let chatAuth = ChatAuthManager(client: api.chat, store: store)
        chatAuthManager = chatAuth
        chatRepository = ChatRepository(client: api.chat, auth: chatAuth)

        isLoggedIn = store.isLoggedIn
        isConsentAccepted = consent.isAccepted

        PushManager.shared.onToken = { token in
            store.fcmToken = token
            store.registeredFcmToken = nil
            Task { await chatAuth.ensureAuthenticated() }
        }
        PushManager.shared.flushIfNeeded()
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
        _ = await chatRepository.logout()
        clearLocalSession()
    }

    /// Локальный выход без обращения к серверу. Нужен после удаления аккаунта,
    /// когда серверная сессия уже уничтожена и логин/регистрация заново создали
    /// бы аккаунт.
    func clearLocalSession() {
        authRepository.logout()
        isLoggedIn = false
    }
}
