import Foundation
import SwiftUI

final class AppContainer: ObservableObject {
    let tokenStore: TokenStore
    let authRepository: AuthRepository
    let newsRepository: NewsRepository
    let videoRepository: VideoRepository
    let chatAuthManager: ChatAuthManager
    let chatRepository: ChatRepository

    @Published var isLoggedIn: Bool

    init() {
        let store = TokenStore()
        tokenStore = store

        let api = API(tokenStore: store)
        authRepository = AuthRepository(client: api.makeup, store: store)
        newsRepository = NewsRepository(client: api.makeup)
        videoRepository = VideoRepository(client: api.makeup)

        let chatAuth = ChatAuthManager(client: api.chat, store: store)
        chatAuthManager = chatAuth
        chatRepository = ChatRepository(client: api.chat, auth: chatAuth)

        isLoggedIn = store.isLoggedIn

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

    func logout() {
        authRepository.logout()
        isLoggedIn = false
    }
}
