import SwiftUI

/// Маршруты навигации. Значения `Hashable`, чтобы складываться в `NavigationPath`.
enum Route: Hashable {
    case conversation(ChatResponse)
    case groupSettings(ChatResponse)
    case newsDetail(Int64)
    case videoDetail(VideoResponse)
    case operatorInfo
}

/// Абстракция навигации (аналог Android `Navigator`): экраны не управляют
/// `NavigationStack` напрямую, а просят роутер перейти на маршрут. Так проще
/// тестировать и добавлять новые переходы в одном месте.
@MainActor
final class Router: ObservableObject {
    @Published var path = NavigationPath()

    func push(_ route: Route) {
        path.append(route)
    }

    func back() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        guard !path.isEmpty else { return }
        path.removeLast(path.count)
    }
}

/// Строит экран по маршруту. Зависимости берутся из `AppContainer`, поэтому
/// экранам не нужно протаскивать репозитории через инициализаторы.
struct RouteDestinationView: View {
    @EnvironmentObject private var container: AppContainer
    let route: Route

    var body: some View {
        switch route {
        case .conversation(let chat):
            ChatConversationView(
                chat: chat,
                repository: container.messageRepository,
                myUserUuid: container.myUserUuid
            )
        case .groupSettings(let chat):
            GroupSettingsView(chat: chat, container: container)
        case .newsDetail(let id):
            NewsDetailView(newsId: id, container: container)
        case .videoDetail(let video):
            VideoDetailView(video: video, container: container)
        case .operatorInfo:
            OperatorInfoView()
        }
    }
}
