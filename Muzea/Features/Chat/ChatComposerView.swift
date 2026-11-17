import SwiftUI

/// Поле ввода с баннером ответа/редактирования, подсказками `@`-упоминаний и
/// кнопкой отправки.
struct ChatComposerView: View {
    @Binding var text: String
    let replyTo: MessageResponse?
    let editing: MessageResponse?
    let myUserUuid: String?
    let usernames: [String]
    let pendingAttachments: [PendingChatAttachment]
    let isUploadingAttachments: Bool
    let onAttach: () -> Void
    let onRemoveAttachment: (String) -> Void
    let onSend: (Int) -> Void
    let onVoiceRecorded: (RecordedVoice) -> Void
    let onVoiceError: (String) -> Void
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
                            HStack(spacing: 4) {
                                Image(systemName: icon(for: attachment.kind))
                                Text(attachment.fileName)
                                    .lineLimit(1)
                                if !attachment.isUploaded {
                                    ProgressView().scaleEffect(0.7)
                                }
                                Button {
                                    onRemoveAttachment(attachment.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
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
                Button(action: onAttach) {
                    Image(systemName: "paperclip")
                        .font(.title3)
                }
                .disabled(editing != nil || (isUploadingAttachments && pendingAttachments.isEmpty))

                ZStack(alignment: .topLeading) {
                    MentionTextEditor(text: $text, selection: $selection)
                    if text.isEmpty {
                        Text(editing == nil ? "Сообщение" : "Новый текст")
                            .foregroundColor(Color(.placeholderText))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 44, maxHeight: 140)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if canSendNow {
                    ChargeSendButton(
                        isEnabled: !isUploadingAttachments
                            && (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || (!pendingAttachments.isEmpty
                                    && pendingAttachments.allSatisfy(\.isUploaded))),
                        icon: editing == nil ? "paperplane.fill" : "checkmark"
                    ) { power in
                        onSend(power)
                    }
                } else {
                    VoiceRecordButton(
                        onRecorded: onVoiceRecorded,
                        onError: onVoiceError
                    )
                }
            }
            .padding(8)
        }
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
