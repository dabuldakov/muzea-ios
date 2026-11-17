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
    @Published var newsTarget: Int64?

    private var observer: NSObjectProtocol?

    init() {
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
        case .news(let id):
            selectedTab = Self.tabNews
            newsTarget = id
        }
    }

    func consumeChatTarget() -> Chat? {
        defer { chatTarget = nil }
        return chatTarget
    }

    func consumeNewsTarget() -> Int64? {
        defer { newsTarget = nil }
        return newsTarget
    }
}
