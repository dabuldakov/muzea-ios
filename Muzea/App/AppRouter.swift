import Foundation

/// Навигация уровня приложения: вкладки и переходы из push/deep link.
/// Экраны читают target и сами пушат маршрут в свой NavigationStack.
@MainActor
final class AppRouter: ObservableObject {
    static let tabNews = 0
    static let tabChats = 1
    static let tabContacts = 2
    static let tabVideos = 3
    static let tabProfile = 4

    @Published var selectedTab = tabNews
    @Published var chatTarget: Chat?
    @Published var chatTargetMessageUuid: String?
    @Published var newsTarget: Int64?
    @Published var videoTarget: Video?
    @Published var sharedText: String?

    private var observer: NSObjectProtocol?

    init() {
        #if DEBUG
        if let tab = ScreenshotBootstrap.initialTab {
            selectedTab = tab
        }
        if let news = ScreenshotBootstrap.initialNews {
            selectedTab = Self.tabNews
            newsTarget = news
        }
        if let chat = ScreenshotBootstrap.initialChat {
            selectedTab = Self.tabChats
            chatTarget = chat
        }
        #endif
        observer = NotificationCenter.default.addObserver(
            forName: PushRouteNotification.name,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let route = note.object as? PushRoute else { return }
            Task { @MainActor in
                self?.handle(route)
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func handle(_ route: PushRoute) {
        switch route {
        case .chat(let target):
            openChat(target)
        case .news(let id):
            selectedTab = Self.tabNews
            newsTarget = id
        }
    }

    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        guard let link = DeepLink.parse(url) else { return false }
        switch link {
        case .chat(let target):
            openChat(target)
        case .news(let id):
            selectedTab = Self.tabNews
            newsTarget = id
        case .share(let text):
            selectedTab = Self.tabChats
            sharedText = text
        }
        return true
    }

    private func openChat(_ target: ChatPushTarget) {
        selectedTab = Self.tabChats
        chatTarget = Chat(
            chatUuid: target.chatUuid,
            chatType: nil,
            title: target.title,
            avatarUrl: target.avatarUrl,
            createdAt: nil,
            updatedAt: nil,
            participantCount: nil,
            lastMessage: nil,
            unreadCount: 0
        )
        chatTargetMessageUuid = target.messageUuid
    }

    func consumeChatTargetMessageUuid() -> String? {
        defer { chatTargetMessageUuid = nil }
        return chatTargetMessageUuid
    }

    func consumeSharedText() -> String? {
        defer { sharedText = nil }
        return sharedText
    }

    func consumeChatTarget() -> Chat? {
        defer { chatTarget = nil }
        return chatTarget
    }

    func consumeNewsTarget() -> Int64? {
        defer { newsTarget = nil }
        return newsTarget
    }

    func openVideo(_ video: Video) {
        selectedTab = Self.tabVideos
        videoTarget = video
    }

    func consumeVideoTarget() -> Video? {
        defer { videoTarget = nil }
        return videoTarget
    }
}
