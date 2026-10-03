import SwiftUI

struct ChatListView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: ChatListViewModel
    @StateObject private var router = Router()
    @State private var showCreateGroup = false

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: ChatListViewModel(repository: container.chatRepository))
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            content
                .navigationTitle("Чаты")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showCreateGroup = true } label: {
                            Image(systemName: "person.3")
                        }
                    }
                }
                .refreshable { await viewModel.load() }
                .sheet(isPresented: $showCreateGroup) {
                    CreateGroupView(container: container) { chat in
                        showCreateGroup = false
                        router.push(.conversation(chat))
                        Task { await viewModel.load() }
                    }
                }
                .navigationDestination(for: Route.self) { RouteDestinationView(route: $0) }
        }
        .environmentObject(router)
        .task { await viewModel.startAutoRefresh() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state.viewState {
        case .list:
            List(viewModel.state.chats) { chat in
                NavigationLink(value: Route.conversation(chat)) {
                    ChatRow(chat: chat)
                }
            }
            .listStyle(.plain)

        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .error:
            VStack(spacing: 8) {
                Image(systemName: "message").font(.largeTitle).foregroundColor(.secondary)
                Text(viewModel.state.error ?? "Ошибка").foregroundColor(.secondary)
            }

        case .empty:
            VStack(spacing: 8) {
                Image(systemName: "message").font(.largeTitle).foregroundColor(.secondary)
                Text("Нет чатов").foregroundColor(.secondary)
            }
        }
    }
}

struct ChatRow: View {
    let chat: ChatResponse

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: ImageURL.chat(chat.avatarUrl), size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(chat.title ?? "Чат").font(.headline).lineLimit(1)

                if let text = chat.lastMessage?.text, !text.isEmpty {
                    let prefix = chat.lastMessage?.senderName.map { "\($0): " } ?? ""
                    Text(prefix + text)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Нет сообщений")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if let createdAt = chat.lastMessage?.createdAt, !createdAt.isEmpty {
                    Text(DateTimeFormat.full(createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let unread = chat.unreadCount, unread > 0 {
                    Text("\(unread)")
                        .font(.caption2).bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
        }
    }
}
