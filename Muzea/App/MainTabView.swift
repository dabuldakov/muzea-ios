import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var appRouter: AppRouter
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @Environment(\.scenePhase) private var scenePhase
    @State private var unreadCount: Int64 = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            tabs
            MiniPlayerView(playback: container.videoPlaybackManager) { video in
                appRouter.openVideo(video)
            }
            .animation(.easeInOut(duration: 0.2), value: container.videoPlaybackManager.activeVideo?.id)
        }
    }

    private var tabs: some View {
        TabView(selection: $appRouter.selectedTab) {
            NewsListView(container: container)
                .tabItem { Label(L10n.tabNews, systemImage: "newspaper") }
                .tag(0)

            ChatListView(container: container)
                .tabItem { Label(L10n.tabChats, systemImage: "message") }
                .badge(unreadCount > 0 ? Int(unreadCount) : 0)
                .tag(1)

            ContactListView(container: container)
                .tabItem { Label(L10n.tabContacts, systemImage: "person.2") }
                .tag(2)

            VideoListView(container: container)
                .tabItem { Label(L10n.tabVideo, systemImage: "play.rectangle") }
                .tag(3)

            ProfileView(container: container)
                .tabItem { Label(L10n.tabProfile, systemImage: "person.crop.circle") }
                .tag(4)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !networkMonitor.isOnline {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                    Text(L10n.noInternet)
                }
                .font(.caption).bold()
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.orange)
            }
        }
        .task {
            while !Task.isCancelled {
                if let count = try? await container.chatSessionRepository.totalUnreadCount() {
                    unreadCount = count
                }
                try? await Task.sleep(nanoseconds: Config.unreadPollInterval)
            }
        }
        // Heartbeat «я на переднем плане»: продлевает серверное окно «в сети»,
        // пока приложение активно. При сворачивании цикл снимается, и сервер
        // догасит статус сам по TTL.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                _ = await container.chatSessionRepository.sendHeartbeat()
                try? await Task.sleep(nanoseconds: Config.heartbeatInterval)
            }
        }
    }
}
