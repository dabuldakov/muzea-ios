import SwiftUI

struct ChatListView: View {
    @StateObject private var viewModel: ChatListViewModel

    private let repository: ChatRepository
    private let myUserUuid: String?

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
            .refreshable { await viewModel.load() }
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
                Text(chat.lastMessage?.text ?? "Нет сообщений")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

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
