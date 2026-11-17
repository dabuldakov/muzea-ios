import SwiftUI

/// Поле ввода с баннером ответа/редактирования, подсказками `@`-упоминаний и
/// кнопкой отправки.
struct ChatComposerView: View {
    @Binding var text: String
    let replyTo: ChatMessage?
    let editing: ChatMessage?
    let myUserUuid: String?
    let usernames: [String]
    let pendingAttachments: [PendingChatAttachment]
    let isUploadingAttachments: Bool
    let onAttach: () -> Void
    let onEmojiGif: () -> Void
    let onRemoveAttachment: (String) -> Void
    let onRetryAttachment: (String) -> Void
    let onSend: (Int) -> Void
    let onVoiceRecorded: (RecordedVoice) -> Void
    let onVoiceError: (String) -> Void
    let onVideoNote: () -> Void
    let onCancel: () -> Void

    @State private var selection = NSRange(location: 0, length: 0)

    private var mentionQuery: MentionSuggestions.Query? {
        MentionSuggestions.resolve(
            text: text,
            cursor: selection.location,
            usernames: usernames
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if let editing {
                banner(
                    title: L10n.editing,
                    preview: MessagePreviewText.preview(editing)
                )
            } else if let replyTo {
                banner(
                    title: L10n.replyBanner(MessagePreviewText.senderName(replyTo, myUserUuid: myUserUuid)),
                    preview: MessagePreviewText.preview(replyTo)
                )
            }

            if let query = mentionQuery {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(query.candidates, id: \.self) { candidate in
                            Button("@\(candidate)") {
                                text = MentionSuggestions.apply(candidate, to: text, query: query)
                                selection = NSRange(
                                    location: query.start + ("@\(candidate) " as NSString).length,
                                    length: 0
                                )
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

            if !pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pendingAttachments) { attachment in
                            pendingAttachmentChip(attachment)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, 6)
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button(action: onAttach) {
                    Image(systemName: "paperclip")
                        .font(.title3)
                }
                .accessibilityLabel(L10n.attach)
                .disabled(editing != nil || (isUploadingAttachments && pendingAttachments.isEmpty))

                Button(action: onEmojiGif) {
                    Image(systemName: "face.smiling")
                        .font(.title3)
                }
                .accessibilityLabel(L10n.emojiGif)
                .disabled(editing != nil)

                ZStack(alignment: .topLeading) {
                    MentionTextEditor(text: $text, selection: $selection)
                    if text.isEmpty {
                        Text(editing == nil ? L10n.messagePlaceholder : L10n.newTextPlaceholder)
                            .foregroundColor(Color(.placeholderText))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .frame(
                    minHeight: Theme.Size.composerMinHeight,
                    maxHeight: Theme.Size.composerMaxHeight
                )
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if canSendNow {
                    ChargeSendButton(
                        isEnabled: canSubmit,
                        icon: editing == nil ? "paperplane.fill" : "checkmark"
                    ) { power in
                        onSend(power)
                    }
                } else {
                    HStack(spacing: 6) {
                        VoiceRecordButton(
                            onRecorded: onVoiceRecorded,
                            onError: onVoiceError
                        )
                        Button(action: onVideoNote) {
                            Image(systemName: "video.fill")
                                .font(.title3)
                                .frame(
                                    width: Theme.Size.iconButton,
                                    height: Theme.Size.iconButton
                                )
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(L10n.videoNote)
                    }
                }
            }
            .padding(8)
        }
    }

    /// Чип вложения: имя, прогресс загрузки или ошибка с повтором.
    @ViewBuilder
    private func pendingAttachmentChip(_ attachment: PendingChatAttachment) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon(for: attachment.kind))
                Text(attachment.fileName)
                    .lineLimit(1)

                if attachment.isUploaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if attachment.error != nil {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                }

                Button {
                    onRemoveAttachment(attachment.id)
                } label: {
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
                onRetryAttachment(attachment.id)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(chipAccessibilityLabel(attachment))
        .accessibilityHint(attachment.error == nil ? "" : L10n.retry)
    }

    private func chipAccessibilityLabel(_ attachment: PendingChatAttachment) -> String {
        if let error = attachment.error {
            return "\(attachment.fileName), \(error)"
        }
        if attachment.isUploaded {
            return attachment.fileName
        }
        let percent = Int((attachment.normalizedProgress * 100).rounded())
        return percent > 0
            ? "\(attachment.fileName), \(percent)%"
            : attachment.fileName
    }

    /// Отправка недоступна, пока хоть одно вложение не загрузилось: иначе
    /// сообщение уйдёт без файла или с ошибкой.
    private var canSubmit: Bool {
        guard !isUploadingAttachments else { return false }
        guard pendingAttachments.allSatisfy(\.isUploaded) else { return false }
        if editing != nil { return true }
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText || !pendingAttachments.isEmpty
    }

    private var canSendNow: Bool {
        editing != nil
            || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !pendingAttachments.isEmpty
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
            .accessibilityLabel(editing == nil ? L10n.cancelReply : L10n.cancelEditing)
            .buttonStyle(.plain)
        }
        .frame(height: 40)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
    }

    private func icon(for kind: AttachmentKind) -> String {
        switch kind {
        case .image: return "photo"
        case .video: return "play.rectangle"
        case .audio: return "waveform"
        case .gif: return "sparkles"
        case .document: return "doc"
        }
    }
}
