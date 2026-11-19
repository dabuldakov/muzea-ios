import SwiftUI

struct ChatListView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var appRouter: AppRouter
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @StateObject private var viewModel: ChatListViewModel
    @StateObject private var router = Router()
    @State private var showCreateGroup = false
    @State private var sharePayload: SharePayload?

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: ChatListViewModel(repository: container.chatRepository))
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            content
                .navigationTitle(L10n.chatList)
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
        // Опрос списка нужен только на корне: в переписке свой поллинг.
        .task(id: router.path.count) {
            guard router.path.count == 0 else { return }
            await viewModel.startAutoRefresh()
        }
        .onAppear {
            openPendingChat()
            if let text = appRouter.consumeSharedText(), !text.isEmpty {
                sharePayload = SharePayload(text: text)
            }
        }
        .onChange(of: networkMonitor.isOnline) { online in
            if online {
                Task { await viewModel.load() }
            }
        }
        .onChange(of: appRouter.chatTarget) { _ in openPendingChat() }
        .onChange(of: appRouter.sharedText) { text in
            if let text, !text.isEmpty {
                sharePayload = SharePayload(text: text)
                _ = appRouter.consumeSharedText()
            }
        }
        .sheet(item: $sharePayload) { payload in
            ShareToChatView(text: payload.text, container: container) { chat in
                router.push(.conversation(chat))
            }
        }
        .onChange(of: router.path.count) { count in
            // Вернулись из переписки: не ждём 8-секундный опрос, сразу
            // подтягиваем счётчики непрочитанных и последние сообщения.
            if count == 0 {
                Task { await viewModel.load() }
            }
        }
    }

    private func openPendingChat() {
        guard let chat = appRouter.consumeChatTarget() else { return }
        router.push(.conversation(chat))
        Task { await viewModel.load() }
    }

    private struct SharePayload: Identifiable {
        let id = UUID()
        let text: String
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state.viewState {
        case .list:
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.state.chats) { chat in
                        NavigationLink(value: Route.conversation(chat)) {
                            ChatRow(chat: chat)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
            .background(Color(.systemGroupedBackground))

        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .error:
            VStack(spacing: 8) {
                Image(systemName: "message").font(.largeTitle).foregroundColor(.secondary)
                Text(viewModel.state.error ?? L10n.error).foregroundColor(.secondary)
            }

        case .empty:
            VStack(spacing: 8) {
                Image(systemName: "message").font(.largeTitle).foregroundColor(.secondary)
                Text(L10n.chatListEmpty).foregroundColor(.secondary)
            }
        }
    }
}

struct ChatRow: View {
    let chat: Chat

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            AvatarView(url: chat.peerDeleted == true ? nil : ImageURL.chat(chat.avatarUrl), size: 48)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(titleText)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let createdAt = chat.lastMessage?.createdAt, !createdAt.isEmpty {
                        Text(DateTimeFormat.full(createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                HStack(alignment: .center, spacing: 8) {
                    Text(previewText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let unread = chat.unreadCount, unread > 0 {
                        Text("\(unread)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .frame(minWidth: 20)
                            .background(Theme.Palette.outgoingStart)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .contentShape(Rectangle())
    }

    private var previewText: String {
        if let text = chat.lastMessage?.text, !text.isEmpty {
            let prefix = chat.lastMessage?.senderName.map { "\($0): " } ?? ""
            return prefix + text
        }
        return L10n.messagesEmpty
    }

    private var titleText: String {
        chat.peerDeleted == true ? L10n.deletedUser : (chat.title ?? L10n.chat)
    }
}
