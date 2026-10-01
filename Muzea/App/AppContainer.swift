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

    func logout() {
        authRepository.logout()
        isLoggedIn = false
    }
}
