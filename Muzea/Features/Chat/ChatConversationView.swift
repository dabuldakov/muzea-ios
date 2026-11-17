import SwiftUI
import UIKit
import UserNotifications
import PhotosUI
import UniformTypeIdentifiers

struct ChatConversationView: View {
    let chat: Chat

    @EnvironmentObject private var router: Router
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @StateObject private var viewModel: ChatConversationViewModel
    @State private var input: String
    @State private var didScrollToUnread = false
    @State private var draftBeforeEdit = ""
    @State private var jumpTarget: String?
    @State private var activeAlert: ActiveAlert?
    @State private var activeSheet: ActiveSheet?
    @State private var forwardTargets: [ChatMessage] = []
    @State private var showAttachMenu = false
    @State private var showPhotoPicker = false
    @State private var showVideoPicker = false
    @State private var showFilePicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var videoItem: PhotosPickerItem?
    @State private var showVideoNoteRecorder = false
    @State private var gallery: GalleryRequest?
    @State private var pendingGalleryAction: GalleryAction?

    init(chat: Chat, myUserUuid: String?, services: ChatConversationServices) {
        self.chat = chat
        _viewModel = StateObject(wrappedValue: ChatConversationViewModel(
            chatUuid: chat.chatUuid,
            myUserUuid: myUserUuid,
            isGroupChat: chat.chatType?.uppercased() == "GROUP",
            services: services
        ))
        _input = State(initialValue: services.drafts.draft(chatUuid: chat.chatUuid) ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.state.pinned.isEmpty {
                PinnedMessagesBar(
                    pinned: viewModel.state.pinned,
                    onOpen: { jumpTarget = $0.messageUuid },
                    onUnpin: {
                        guard let first = viewModel.state.pinned.first else { return }
                        Task { await viewModel.togglePin(first) }
                    }
                )
            }

            if viewModel.state.isSelecting {
                selectionBar
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.state.messages) { message in
                            row(for: message)
                                .id(message.messageUuid)
                                .transition(.opacity)
                        }
                    }
                    .padding(8)
                    .animation(.easeInOut(duration: 0.18), value: viewModel.state.messages.count)
                }
                .onChange(of: viewModel.state.messages.count) { _ in
                    scroll(proxy)
                }
                .onChange(of: jumpTarget) { target in
                    guard let target else { return }
                    withAnimation { proxy.scrollTo(target, anchor: .center) }
                    jumpTarget = nil
                }
                .onAppear { scroll(proxy) }
            }

            if chat.peerDeleted == true {
                // Аккаунт собеседника деактивирован: история видна, отправка нет.
                Text(L10n.userDeletedBanner)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
            } else if !viewModel.state.isSelecting {
                ChatComposerView(
                    text: $input,
                    replyTo: viewModel.state.replyTo,
                    editing: viewModel.state.editing,
                    myUserUuid: viewModel.myUserUuid,
                    usernames: viewModel.mentionCandidates,
                    pendingAttachments: viewModel.state.pendingAttachments,
                    isUploadingAttachments: viewModel.state.isUploadingAttachments,
                    onAttach: { showAttachMenu = true },
                    onEmojiGif: { activeSheet = .emojiGif },
                    onRemoveAttachment: { viewModel.removePendingAttachment($0) },
                    onRetryAttachment: { id in
                        Task { await viewModel.retryPendingAttachment(id) }
                    },
                    onSend: { power in send(power: power) },
                    onVoiceRecorded: { recorded in
                        Task { _ = await viewModel.sendVoice(recorded) }
                    },
                    onVoiceError: { viewModel.reportValidationError($0) },
                    onVideoNote: { showVideoNoteRecorder = true },
                    onCancel: cancelComposer
                )
            }
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.state.isSelecting)
        .animation(.easeInOut(duration: 0.18), value: viewModel.state.pinned.count)
        .navigationTitle(chat.title ?? L10n.chat)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.exitSelection()
                    router.push(.groupSettings(chat))
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel(L10n.aboutChat)
            }
        }
        .task { await viewModel.start() }
        .onAppear {
            ActiveChatTracker.shared.enter(chat.chatUuid)
            UNUserNotificationCenter.current().removeDeliveredNotifications(
                withIdentifiers: ["chat_\(chat.chatUuid)"]
            )
        }
        .onDisappear {
            ActiveChatTracker.shared.leave(chat.chatUuid)
            viewModel.saveDraft(input)
            viewModel.exitSelection()
        }
        .onChange(of: input) { value in
            viewModel.saveDraft(value)
        }
        .onChange(of: networkMonitor.isOnline) { online in
            guard online else { return }
            Task {
                await viewModel.retryPending(force: true)
                await viewModel.retryPendingAttachments()
            }
        }
        .onChange(of: viewModel.state.error) { value in
            if let value { activeAlert = .error(value) }
        }
        .onChange(of: viewModel.state.notice) { value in
            if let value { activeAlert = .notice(value) }
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .error(let message):
                return Alert(
                    title: Text(L10n.error),
                    message: Text(message),
                    dismissButton: .default(Text("OK")) { viewModel.consumeError() }
                )
            case .notice(let message):
                return Alert(
                    title: Text(message),
                    dismissButton: .default(Text("OK")) { viewModel.consumeNotice() }
                )
            case .delete(let message):
                return Alert(
                    title: Text(L10n.deleteMessageTitle),
                    message: Text(L10n.deleteMessageBody),
                    primaryButton: .destructive(Text(L10n.delete)) {
                        Task { await viewModel.deleteMessage(message) }
                    },
                    secondaryButton: .cancel()
                )
            case .deleteSelected:
                return Alert(
                    title: Text(L10n.deleteSelectedTitle),
                    message: Text(L10n.deleteSelectedBody),
                    primaryButton: .destructive(Text(L10n.delete)) {
                        Task { await viewModel.deleteSelected() }
                    },
                    secondaryButton: .cancel()
                )
            case .block(let message):
                return Alert(
                    title: Text(L10n.blockTitle),
                    message: Text(L10n.blockBody),
                    primaryButton: .destructive(Text(L10n.block)) {
                        if let uuid = message.senderUuid {
                            Task { await viewModel.block(userUuid: uuid) }
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onChange(of: photoItems) { items in
            guard !items.isEmpty else { return }
            Task { await addPhotos(items) }
        }
        .onChange(of: videoItem) { item in
            guard let item else { return }
            Task { await addVideo(item) }
        }
        .confirmationDialog(L10n.attachment, isPresented: $showAttachMenu) {
            Button(L10n.photo) { showPhotoPicker = true }
            Button(L10n.video) { showVideoPicker = true }
            Button(L10n.videoNote) { showVideoNoteRecorder = true }
            Button(L10n.file) { showFilePicker = true }
            Button(L10n.cancel, role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $photoItems,
            maxSelectionCount: AttachmentPolicy.maxAttachmentsPerMessage,
            matching: .images
        )
        .photosPicker(isPresented: $showVideoPicker, selection: $videoItem, matching: .videos)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.data, .content],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await addFile(url) }
            }
        }
        .sheet(item: $gallery, onDismiss: runPendingGalleryAction) { request in
            ImageGalleryViewer(
                attachments: request.images,
                startIndex: request.startIndex,
                senderName: request.senderName,
                createdAt: request.message.createdAt,
                onReply: {
                    pendingGalleryAction = .reply(request.message)
                    gallery = nil
                },
                onForward: {
                    pendingGalleryAction = .forward(request.message)
                    gallery = nil
                }
            )
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {            case .forward:
                ForwardChatPickerView(chats: viewModel.state.forwardChats) { chatUuid, comment in
                    let targets = forwardTargets
                    forwardTargets = []
                    Task {
                        await viewModel.forward(messages: targets, toChatUuid: chatUuid, comment: comment)
                    }
                }
            case .details(let message):
                MessageStatusSheet(
                    message: message,
                    receipts: viewModel.state.receipts,
                    statuses: viewModel.state.messageStatuses[message.messageUuid] ?? [],
                    myUserUuid: viewModel.myUserUuid
                )
            case .reaction(let message):
                ReactionPickerSheet(
                    recent: viewModel.recentReactions,
                    all: ReactionCatalog.all
                ) { emoji in
                    Task { await viewModel.toggleReaction(message, emoji: emoji) }
                }
            case .report(let message):
                ReportReasonSheet { reason in
                    Task { await viewModel.report(message, reason: reason) }
                }
            case .emojiGif:
                EmojiGifSheet(
                    repository: container.gifRepository,
                    chatUuid: chat.chatUuid,
                    onEmoji: { emoji in input += emoji },
                    onGif: { gif in Task { await viewModel.sendGif(gif) } }
                )
            }
        }
        .fullScreenCover(isPresented: $showVideoNoteRecorder) {
            VideoNoteRecorderSheet { note in
                Task { _ = await viewModel.sendVideoNote(note) }
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(for message: ChatMessage) -> some View {
        let isMine = message.senderUuid != nil && message.senderUuid == viewModel.myUserUuid
        let selected = viewModel.state.selection.contains(message.messageUuid)

        MessageRow(
            message: message,
            isMine: isMine,
            showSenderName: viewModel.isGroupChat && !isMine,
            replyTarget: replyTarget(for: message),
            status: viewModel.state.statuses[message.messageUuid],
            isSelected: selected,
            myUserUuid: viewModel.myUserUuid,
            onReaction: { emoji in
                Task { await viewModel.toggleReaction(message, emoji: emoji) }
            },
            onOpenImage: { index in
                gallery = GalleryRequest(message: message, tappedIndex: index)
            }
        )
        .overlay(alignment: .topTrailing) {
            if viewModel.state.isSelecting && selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .padding(4)
            }
        }
        .onTapGesture {
            if viewModel.state.isSelecting {
                viewModel.toggleSelection(message)
            }
        }
        .onAppear {
            Task { await viewModel.markReadUpTo(message) }
        }
        .contextMenu {
            contextMenu(for: message, isMine: isMine)
        }
    }

    @ViewBuilder
    private func contextMenu(for message: ChatMessage, isMine: Bool) -> some View {
        let result = MessageActionsBuilder.build(
            message: message,
            myUserUuid: viewModel.myUserUuid,
            isGroupChat: viewModel.isGroupChat,
            failedMessages: viewModel.state.failedMessages
        )

        ForEach(result.actions, id: \.self) { action in
            switch action {
            case .react:
                Button {
                    activeSheet = .reaction(message)
                } label: {
                    Label(L10n.reaction, systemImage: "face.smiling")
                }
            case .retry:
                Button {
                    Task { await viewModel.retry(message) }
                } label: {
                    Label(L10n.retry, systemImage: "arrow.clockwise")
                }
            case .copy:
                Button {
                    UIPasteboard.general.string = message.text
                } label: {
                    Label(L10n.copy, systemImage: "doc.on.doc")
                }
            case .reply:
                Button {
                    viewModel.beginReply(to: message)
                } label: {
                    Label(L10n.reply, systemImage: "arrowshape.turn.up.left")
                }
            case .select:
                Button {
                    viewModel.enterSelection(with: message)
                } label: {
                    Label(L10n.select, systemImage: "checkmark.circle")
                }
            case .edit:
                Button {
                    draftBeforeEdit = input
                    input = message.text ?? ""
                    viewModel.beginEdit(message)
                } label: {
                    Label(L10n.edit, systemImage: "pencil")
                }
            case .delete:
                Button(role: .destructive) {
                    activeAlert = .delete(message)
                } label: {
                    Label(L10n.delete, systemImage: "trash")
                }
            case .forward:
                Button {
                    openForward([message])
                } label: {
                    Label(L10n.forward, systemImage: "arrowshape.turn.up.right")
                }
            case .pin:
                Button {
                    Task { await viewModel.togglePin(message) }
                } label: {
                    Label(L10n.pin, systemImage: "pin")
                }
            case .unpin:
                Button {
                    Task { await viewModel.togglePin(message) }
                } label: {
                    Label(L10n.unpin, systemImage: "pin.slash")
                }
            case .status:
                Button {
                    activeSheet = .details(message)
                    Task { await viewModel.loadMessageStatuses(for: message) }
                } label: {
                    Label(L10n.details, systemImage: "info.circle")
                }
            case .report:
                Button {
                    activeSheet = .report(message)
                } label: {
                    Label(L10n.report, systemImage: "exclamationmark.bubble")
                }
            case .block:
                Button(role: .destructive) {
                    activeAlert = .block(message)
                } label: {
                    Label(L10n.block, systemImage: "hand.raised")
                }
            }
        }
    }

    // MARK: - Selection bar

    private var selectionBar: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.exitSelection()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel(L10n.exitSelection)

            Text(L10n.selectedCount(viewModel.state.selection.count))
                .font(.subheadline).bold()

            Spacer()

            Button {
                openForward(viewModel.selectedMessages)
            } label: {
                Image(systemName: "arrowshape.turn.up.right")
            }
            .accessibilityLabel(L10n.forwardSelected)
            .disabled(viewModel.selectedMessages.isEmpty)

            Button {
                activeAlert = .deleteSelected
            } label: {
                Image(systemName: "trash")
            }
            .accessibilityLabel(L10n.deleteSelected)
            .disabled(viewModel.selectedMessages.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Actions

    private func addPhotos(_ items: [PhotosPickerItem]) async {
        defer { photoItems = [] }
        for (index, item) in items.prefix(AttachmentPolicy.maxAttachmentsPerMessage).enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                viewModel.reportValidationError(L10n.errorImageRead)
                continue
            }
            guard let prepared = ImagePreparation.jpeg(from: data) else {
                viewModel.reportValidationError(L10n.errorImageUnsupported)
                continue
            }
            await viewModel.addImage(
                data: prepared.data,
                fileName: "photo_\(Int(Date().timeIntervalSince1970))_\(index).jpg",
                width: prepared.width,
                height: prepared.height
            )
        }
    }

    private func addVideo(_ item: PhotosPickerItem) async {
        defer { videoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            viewModel.reportValidationError(L10n.errorVideoRead)
            return
        }
        let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "mov"
        await viewModel.addVideo(
            data: data,
            fileName: "video_\(Int(Date().timeIntervalSince1970)).\(ext)",
            duration: nil
        )
    }

    private func addFile(_ url: URL) async {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            viewModel.reportValidationError(L10n.errorFileRead)
            return
        }
        let fileName = url.lastPathComponent
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"

        let kind = AttachmentPolicy.rule(for: fileName)?.kind ?? .document
        if kind == .video {
            await viewModel.addVideo(data: data, fileName: fileName, duration: nil)
        } else if kind == .audio {
            await viewModel.addAudio(data: data, fileName: fileName, duration: nil)
        } else {
            await viewModel.addFile(data: data, fileName: fileName, mimeType: mime)
        }
    }

    private func send(power: Int) {
        let text = input
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !viewModel.state.pendingAttachments.isEmpty else { return }
        let wasEditing = viewModel.state.editing != nil
        input = ""
        Task {
            let ok = await viewModel.send(text, power: power)
            if ok {
                Haptics.success()
                draftBeforeEdit = ""
                viewModel.saveDraft("")
            } else if wasEditing {
                // Неудачную правку возвращаем в поле, чтобы можно было повторить.
                input = text
            }
            if !wasEditing {
                viewModel.cancelComposer()
            }
        }
    }

    private func cancelComposer() {
        if viewModel.state.editing != nil {
            input = draftBeforeEdit
            draftBeforeEdit = ""
        }
        viewModel.cancelComposer()
    }

    private func runPendingGalleryAction() {
        guard let action = pendingGalleryAction else { return }
        pendingGalleryAction = nil
        switch action {
        case .reply(let message):
            viewModel.beginReply(to: message)
        case .forward(let message):
            openForward([message])
        }
    }

    private func openForward(_ messages: [ChatMessage]) {
        guard !messages.isEmpty else { return }
        forwardTargets = messages
        activeSheet = .forward
        Task { await viewModel.loadForwardChats() }
    }

    private func replyTarget(for message: ChatMessage) -> ChatMessage? {
        guard let uuid = message.replyToMessageUuid else { return nil }
        return viewModel.state.messages.first { $0.messageUuid == uuid }
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        guard !viewModel.state.messages.isEmpty else { return }

        if !didScrollToUnread {
            didScrollToUnread = true
            let unread = Int(chat.unreadCount ?? 0)
            let index = unread > 0
                ? max(0, viewModel.state.messages.count - unread)
                : viewModel.state.messages.count - 1
            proxy.scrollTo(viewModel.state.messages[index].messageUuid, anchor: .top)
        } else if let last = viewModel.state.messages.last {
            proxy.scrollTo(last.messageUuid, anchor: .bottom)
        }
    }
}

private enum ActiveSheet: Identifiable {
    case forward
    case details(ChatMessage)
    case reaction(ChatMessage)
    case report(ChatMessage)
    case emojiGif

    var id: String {
        switch self {
        case .forward: return "forward"
        case .details(let message): return "details-\(message.messageUuid)"
        case .reaction(let message): return "reaction-\(message.messageUuid)"
        case .report(let message): return "report-\(message.messageUuid)"
        case .emojiGif: return "emoji-gif"
        }
    }
}

private enum ActiveAlert: Identifiable {
    case error(String)
    case notice(String)
    case delete(ChatMessage)
    case deleteSelected
    case block(ChatMessage)

    var id: String {
        switch self {
        case .error(let message): return "error-\(message)"
        case .notice(let message): return "notice-\(message)"
        case .delete(let message): return "delete-\(message.messageUuid)"
        case .deleteSelected: return "delete-selected"
        case .block(let message): return "block-\(message.messageUuid)"
        }
    }
}
