import SwiftUI

/// Выбор чата для текста из Share Extension/ссылк�� `muzea://share`.
struct ShareToChatView: View {
    let text: String
    let container: AppContainer
    let onSent: (Chat) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var chats: [Chat] = []
    @State private var isLoading = true
    @State private var sendingId: String?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if chats.isEmpty {
                    Text(L10n.chatListEmpty).foregroundColor(.secondary)
                } else {
                    List(chats) { chat in
                        Button {
                            Task { await send(to: chat) }
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(
                                    url: chat.peerDeleted == true ? nil : ImageURL.chat(chat.avatarUrl),
                                    size: 40
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chat.title ?? L10n.chat)
                                        .foregroundColor(.primary)
                                    Text(text)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if sendingId == chat.chatUuid {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(sendingId != nil)
                    }
                }
            }
            .navigationTitle(L10n.sendToChat)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
            .task {
                do {
                    chats = try await container.chatRepository.loadChats()
                } catch {
                    self.error = error.localizedDescription
                }
                isLoading = false
            }
            .alert(L10n.error, isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func send(to chat: Chat) async {
        sendingId = chat.chatUuid
        defer { sendingId = nil }
        do {
            _ = try await container.messageRepository.sendMessage(
                chatUuid: chat.chatUuid,
                text: text,
                replyToMessageUuid: nil,
                clientMessageId: UUID().uuidString,
                power: 0
            )
            dismiss()
            onSent(chat)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
