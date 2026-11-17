import SwiftUI

/// Один пузырь сообщения: цитата ответа, пересылка, текст, реакции, время и
/// галочки статуса. Вся логика «моё/чужое» приходит снаружи.
struct MessageRow: View {
    let message: ChatMessage
    let isMine: Bool
    let showSenderName: Bool
    let replyTarget: ChatMessage?
    let status: MessageDeliveryStatus?
    let isSelected: Bool
    let myUserUuid: String?
    let onReaction: (String) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMine { Spacer(minLength: 40) }

            if !isMine {
                AvatarView(
                    url: message.senderDeleted == true ? nil : ImageURL.chat(message.senderAvatar),
                    size: 28
                )
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                if !isMine, showSenderName {
                    Text(senderName).font(.caption2).foregroundColor(.secondary)
                }

                if message.forwardedFromMessageUuid != nil {
                    Label("Переслано", systemImage: "arrowshape.turn.up.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if hasBubble {
                    VStack(alignment: .leading, spacing: 4) {
                        if message.replyToMessageUuid != nil {
                            replyQuote
                        }
                        if let text = message.text, !text.isEmpty {
                            Text(text)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleColor)
                    .foregroundColor(isMine ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.accentColor, lineWidth: isSelected ? 2 : 0)
                    )
                }

                if let attachments = message.attachments, !attachments.isEmpty {
                    MessageAttachmentsView(
                        attachments: attachments,
                        isMine: isMine,
                        messageType: message.messageType
                    )
                }

                if let url = LinkPreviewExtractor.firstURL(in: message.text) {
                    LinkPreviewView(url: url)
                }

                if let reactions = message.reactions, !reactions.isEmpty {
                    reactionRow(reactions)
                }

                HStack(spacing: 4) {
                    if let power = message.power, power > 0 {
                        Label("\(power)%", systemImage: "bolt.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    if message.isEdited == true {
                        Text("изм.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if let createdAt = message.createdAt, !createdAt.isEmpty {
                        Text(DateTimeFormat.time(createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if isMine {
                        MessageStatusIcon(status: status)
                    }
                }
            }

            if !isMine { Spacer(minLength: 40) }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
    }

    private var replyQuote: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(MessagePreviewText.senderName(replyTarget, myUserUuid: myUserUuid))
                    .font(.caption2).bold()
                Text(MessagePreviewText.preview(replyTarget))
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundColor(isMine ? .white.opacity(0.9) : .secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 220, alignment: .leading)
    }

    private func reactionRow(_ reactions: [MessageReaction]) -> some View {
        HStack(spacing: 4) {
            ForEach(reactions, id: \.emoji) { reaction in
                Button {
                    onReaction(reaction.emoji)
                } label: {
                    HStack(spacing: 2) {
                        Text(reaction.emoji).font(.caption)
                        if reaction.count > 1 {
                            Text("\(reaction.count)").font(.caption2)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(reaction.mine ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bubbleColor: Color {
        isMine ? Color.accentColor.opacity(0.85) : Color(.secondarySystemBackground)
    }

    private var hasBubble: Bool {
        if message.replyToMessageUuid != nil { return true }
        return !(message.text ?? "").isEmpty
    }

    private var senderName: String {
        if message.senderDeleted == true { return "Удалённый пользователь" }
        return message.senderName ?? "Участник"
    }
}

/// Галочки статуса собственного сообщения.
struct MessageStatusIcon: View {
    let status: MessageDeliveryStatus?

    var body: some View {
        Group {
            switch status {
            case .sending:
                Image(systemName: "clock")
            case .failed:
                Image(systemName: "exclamationmark.circle")
            case .sent:
                Image(systemName: "checkmark")
            case .delivered:
                Image(systemName: "checkmark.circle")
            case .read:
                Image(systemName: "checkmark.circle.fill")
            case .none:
                EmptyView()
            }
        }
        .font(.caption2)
        .foregroundColor(status == .read ? .accentColor : .secondary)
    }
}
