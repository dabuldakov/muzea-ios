import SwiftUI
import UIKit

struct ChatConversationView: View {
    let chat: ChatResponse
    let repository: ChatRepository
    let myUserUuid: String?

    @StateObject private var viewModel: ChatConversationViewModel
    @State private var input = ""
    @State private var didScrollToUnread = false

    init(chat: ChatResponse, repository: ChatRepository, myUserUuid: String?) {
        self.chat = chat
        self.repository = repository
        self.myUserUuid = myUserUuid
        _viewModel = StateObject(wrappedValue: ChatConversationViewModel(
            chatUuid: chat.chatUuid,
            repository: repository,
            myUserUuid: myUserUuid
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            MessageRow(
                                message: message,
                                isMine: message.senderUuid != nil && message.senderUuid == myUserUuid
                            )
                            .id(message.messageUuid)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    scroll(proxy)
                }
                .onAppear { scroll(proxy) }
            }

            HStack(spacing: 8) {
                TextField("Сообщение", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)

                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(8)
        }
        .navigationTitle(chat.title ?? "Чат")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    GroupSettingsView(chat: chat, repository: repository, myUserUuid: myUserUuid)
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .task { await viewModel.start() }
    }

    private func send() {
        let text = input
        input = ""
        Task { await viewModel.send(text) }
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        guard !viewModel.messages.isEmpty else { return }

        if !didScrollToUnread {
            didScrollToUnread = true
            let unread = Int(chat.unreadCount ?? 0)
            let index = unread > 0
                ? max(0, viewModel.messages.count - unread)
                : viewModel.messages.count - 1
            proxy.scrollTo(viewModel.messages[index].messageUuid, anchor: .top)
        } else if let last = viewModel.messages.last {
            proxy.scrollTo(last.messageUuid, anchor: .bottom)
        }
    }
}

struct MessageRow: View {
    let message: MessageResponse
    let isMine: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMine { Spacer(minLength: 40) }

            if !isMine {
                AvatarView(url: ImageURL.chat(message.senderAvatar), size: 28)
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                if !isMine, let name = message.senderName, !name.isEmpty {
                    Text(name).font(.caption2).foregroundColor(.secondary)
                }
                Text(message.text ?? "")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isMine ? Color.accentColor.opacity(0.85) : Color(.secondarySystemBackground))
                    .foregroundColor(isMine ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                if let createdAt = message.createdAt, !createdAt.isEmpty {
                    Text(DateTimeFormat.full(createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if !isMine { Spacer(minLength: 40) }
        }
    }
}
