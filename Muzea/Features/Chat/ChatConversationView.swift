import SwiftUI
import UIKit

struct ChatConversationView: View {
    let chat: ChatResponse

    @EnvironmentObject private var router: Router
    @StateObject private var viewModel: ChatConversationViewModel
    @State private var input: String
    @State private var didScrollToUnread = false
    @State private var draftBeforeEdit = ""
    @State private var jumpTarget: String?
    @State private var activeAlert: ActiveAlert?
    @State private var forwardTargets: [MessageResponse] = []
    @State private var activeSheet: ActiveSheet?
    @State private var forwardTargets: [MessageResponse] = []

    init(chat: ChatResponse, myUserUuid: String?, services: ChatConversationServices) {
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
                        }
                    }
                    .padding(8)
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
                Text("Пользователь удалён")
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
                    onSend: { power in send(power: power) },
                    onCancel: cancelComposer
                )
            }
        }
        .navigationTitle(chat.title ?? "Чат")
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
            }
        }
        .task { await viewModel.start() }
        .onDisappear {
            viewModel.saveDraft(input)
            viewModel.exitSelection()
        }
        .onChange(of: input) { value in
            viewModel.saveDraft(value)
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
                    title: Text("Ошибка"),
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
                    title: Text("Удалить сообщение?"),
                    message: Text("Сообщение исчезнет у всех участников."),
                    primaryButton: .destructive(Text("Удалить")) {
                        Task { await viewModel.deleteMessage(message) }
                    },
                    secondaryButton: .cancel()
                )
            case .deleteSelected:
                return Alert(
                    title: Text("Удалить выбранные?"),
                    message: Text("Выбранные сообщения исчезнут у всех участников."),
                    primaryButton: .destructive(Text("Удалить")) {
                        Task { await viewModel.deleteSelected() }
                    },
                    secondaryButton: .cancel()
                )
            case .block(let message):
                return Alert(
                    title: Text("Заблокировать пользователя?"),
                    message: Text("Он больше не сможет писать вам, а контакт будет удалён."),
                    primaryButton: .destructive(Text("Заблокировать")) {
                        if let uuid = message.senderUuid {
                            Task { await viewModel.block(userUuid: uuid) }
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .forward:
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
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(for message: MessageResponse) -> some View {
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
    private func contextMenu(for message: MessageResponse, isMine: Bool) -> some View {
        let result = MessageActionsBuilder.build(
            message: message,
            myUserUuid: viewModel.myUserUuid,
            isGroupChat: viewModel.isGroupChat
        )

        ForEach(result.actions, id: \.self) { action in
            switch action {
            case .react:
                Button {
                    activeSheet = .reaction(message)
                } label: {
                    Label("Реакция", systemImage: "face.smiling")
                }
            case .copy:
                Button {
                    UIPasteboard.general.string = message.text
                } label: {
                    Label("Копировать", systemImage: "doc.on.doc")
                }
            case .reply:
                Button {
                    viewModel.beginReply(to: message)
                } label: {
                    Label("Ответить", systemImage: "arrowshape.turn.up.left")
                }
            case .select:
                Button {
                    viewModel.enterSelection(with: message)
                } label: {
                    Label("Выбрать", systemImage: "checkmark.circle")
                }
            case .edit:
                Button {
                    draftBeforeEdit = input
                    input = message.text ?? ""
                    viewModel.beginEdit(message)
                } label: {
                    Label("Изменить", systemImage: "pencil")
                }
            case .delete:
                Button(role: .destructive) {
                    activeAlert = .delete(message)
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
            case .forward:
                Button {
                    openForward([message])
                } label: {
                    Label("Переслать", systemImage: "arrowshape.turn.up.right")
                }
            case .pin:
                Button {
                    Task { await viewModel.togglePin(message) }
                } label: {
                    Label("Закрепить", systemImage: "pin")
                }
            case .unpin:
                Button {
                    Task { await viewModel.togglePin(message) }
                } label: {
                    Label("Открепить", systemImage: "pin.slash")
                }
            case .status:
                Button {
                    activeSheet = .details(message)
                    Task { await viewModel.loadMessageStatuses(for: message) }
                } label: {
                    Label("Детали", systemImage: "info.circle")
                }
            case .report:
                Button {
                    activeSheet = .report(message)
                } label: {
                    Label("Пожаловаться", systemImage: "exclamationmark.bubble")
                }
            case .block:
                Button(role: .destructive) {
                    activeAlert = .block(message)
                } label: {
                    Label("Заблокировать", systemImage: "hand.raised")
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

            Text("Выбрано: \(viewModel.state.selection.count)")
                .font(.subheadline).bold()

            Spacer()

            Button {
                openForward(viewModel.selectedMessages)
            } label: {
                Image(systemName: "arrowshape.turn.up.right")
            }
            .disabled(viewModel.selectedMessages.isEmpty)

            Button {
                activeAlert = .deleteSelected
            } label: {
                Image(systemName: "trash")
            }
            .disabled(viewModel.selectedMessages.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Actions

    private func send(power: Int) {
        let text = input
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let wasEditing = viewModel.state.editing != nil
        input = ""
        Task {
            let ok = await viewModel.send(text, power: power)
            if ok {
                draftBeforeEdit = ""
                viewModel.saveDraft("")
            } else {
                // Не затираем текст, если пользователь уже начал печатать новое.
                if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    input = text
                    viewModel.saveDraft(text)
                }
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

    private func openForward(_ messages: [MessageResponse]) {
        guard !messages.isEmpty else { return }
        forwardTargets = messages
        activeSheet = .forward
        Task { await viewModel.loadForwardChats() }
    }

    private func replyTarget(for message: MessageResponse) -> MessageResponse? {
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
    case details(MessageResponse)
    case reaction(MessageResponse)
    case report(MessageResponse)

    var id: String {
        switch self {
        case .forward: return "forward"
        case .details(let message): return "details-\(message.messageUuid)"
        case .reaction(let message): return "reaction-\(message.messageUuid)"
        case .report(let message): return "report-\(message.messageUuid)"
        }
    }
}

private enum ActiveAlert: Identifiable {
    case error(String)
    case notice(String)
    case delete(MessageResponse)
    case deleteSelected
    case block(MessageResponse)

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
