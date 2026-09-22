import SwiftUI

struct ChatListView: View {
    @StateObject private var viewModel: ChatListViewModel

    private let repository: ChatRepository
    private let myUserUuid: String?

    @State private var showCreateGroup = false
    @State private var openedChat: ChatResponse?

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: ChatListViewModel(repository: container.chatRepository))
        repository = container.chatRepository
        myUserUuid = JWT.subject(from: container.tokenStore.chatToken)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.chats.isEmpty {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "message").font(.largeTitle).foregroundColor(.secondary)
                            Text(viewModel.error ?? "Нет чатов").foregroundColor(.secondary)
                        }
                    }
                } else {
                    List(viewModel.chats) { chat in
                        NavigationLink {
                            ChatConversationView(chat: chat, repository: repository, myUserUuid: myUserUuid)
                        } label: {
                            ChatRow(chat: chat)
                        }
                    }
                    .listStyle(.plain)
                }
            }
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
                CreateGroupView(repository: repository) { chat in
                    openedChat = chat
                    Task { await viewModel.load() }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { openedChat != nil },
                set: { if !$0 { openedChat = nil } }
            )) {
                if let openedChat {
                    ChatConversationView(chat: openedChat, repository: repository, myUserUuid: myUserUuid)
                }
            }
        }
        .task { await viewModel.startAutoRefresh() }
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
