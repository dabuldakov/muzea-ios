import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var selection = 0
    @State private var unreadCount: Int64 = 0

    var body: some View {
        TabView(selection: $selection) {
            NewsListView(container: container)
                .tabItem { Label("Новости", systemImage: "newspaper") }
                .tag(0)

            ChatListView(container: container)
                .tabItem { Label("Чаты", systemImage: "message") }
                .badge(unreadCount > 0 ? Int(unreadCount) : 0)
                .tag(1)

            ContactListView(container: container)
                .tabItem { Label("Контакты", systemImage: "person.2") }
                .tag(2)

            VideoListView(container: container)
                .tabItem { Label("Видео", systemImage: "play.rectangle") }
                .tag(3)

            ProfileView(container: container)
                .tabItem { Label("Профиль", systemImage: "person.crop.circle") }
                .tag(4)
        }
        .task {
            while !Task.isCancelled {
                if let count = try? await container.chatRepository.totalUnreadCount() {
                    unreadCount = count
                }
                try? await Task.sleep(nanoseconds: Config.unreadPollInterval)
            }
        }
    }
}
