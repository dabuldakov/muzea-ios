import SwiftUI

/// Чип вложения в композере: имя, прогресс загрузки или ошибка с повтором.
/// Отделён от `ChatComposerView`, чтобы композер занимался вводом и отправкой,
/// а не деталями состояния загрузки.
struct PendingAttachmentChip: View {
    let attachment: PendingChatAttachment
    let onRemove: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                Text(attachment.fileName)
                    .lineLimit(1)

                if attachment.isUploaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if attachment.error != nil {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                }

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                }
                .accessibilityLabel(L10n.removeAttachment)
                .buttonStyle(.plain)
            }

            if let error = attachment.error {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(2)
            } else if !attachment.isUploaded {
                if attachment.normalizedProgress > 0 {
                    ProgressView(value: attachment.normalizedProgress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                        .frame(width: 120)
                } else {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 120, alignment: .leading)
                }
            }
        }
        .font(.caption)
        .frame(maxWidth: 180, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, 5)
        .background(Theme.Palette.incomingBubble)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.field))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.field)
                .stroke(attachment.error == nil ? Color.clear : Color.red.opacity(0.6))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if attachment.error != nil {
                onRetry()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(attachment.accessibilityLabel())
        .accessibilityHint(attachment.error == nil ? "" : L10n.retry)
    }

    private var icon: String {
        switch attachment.kind {
        case .image: return "photo"
        case .video: return "play.rectangle"
        case .audio: return "waveform"
        case .gif: return "sparkles"
        case .document: return "doc"
        }
    }
}
