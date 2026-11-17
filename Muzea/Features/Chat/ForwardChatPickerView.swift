import SwiftUI

/// Выбор чата для пересылки сообщений и необязательный комментарий.
struct ForwardChatPickerView: View {
    let chats: [Chat]
    let onSend: (String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var comment = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Комментарий (необязательно)", text: $comment, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("Куда переслать") {
                    if chats.isEmpty {
                        Text("Нет других чатов").foregroundColor(.secondary)
                    }
                    ForEach(chats) { chat in
                        Button {
                            onSend(chat.chatUuid, comment)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(
                                    url: chat.peerDeleted == true ? nil : ImageURL.chat(chat.avatarUrl),
                                    size: 40
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title(chat)).foregroundColor(.primary)
                                    if let text = chat.lastMessage?.text, !text.isEmpty {
                                        Text(text)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Переслать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func title(_ chat: Chat) -> String {
        chat.peerDeleted == true ? "Удалённый пользователь" : (chat.title ?? "Чат")
    }
}
