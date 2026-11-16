import SwiftUI

/// Поле ввода с баннером ответа/редактирования, подсказками `@`-упоминаний и
/// кнопкой отправки.
struct ChatComposerView: View {
    @Binding var text: String
    let replyTo: MessageResponse?
    let editing: MessageResponse?
    let myUserUuid: String?
    let usernames: [String]
    let onSend: () -> Void
    let onCancel: () -> Void

    private var mentionQuery: MentionSuggestions.Query? {
        MentionSuggestions.resolve(text: text, usernames: usernames)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let editing {
                banner(
                    title: "Редактирование",
                    preview: MessagePreviewText.preview(editing)
                )
            } else if let replyTo {
                banner(
                    title: "Ответ: \(MessagePreviewText.senderName(replyTo, myUserUuid: myUserUuid))",
                    preview: MessagePreviewText.preview(replyTo)
                )
            }

            if let query = mentionQuery {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(query.candidates, id: \.self) { candidate in
                            Button("@\(candidate)") {
                                text = MentionSuggestions.apply(candidate, to: text, query: query)
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField(editing == nil ? "Сообщение" : "Новый текст", text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .textFieldStyle(.roundedBorder)

                Button(action: onSend) {
                    Image(systemName: editing == nil ? "paperplane.fill" : "checkmark.circle.fill")
                        .font(.title3)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(8)
        }
    }

    private func banner(title: String, preview: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption).bold()
                Text(preview).font(.caption2).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 40)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
    }
}
