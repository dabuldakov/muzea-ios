import SwiftUI

struct ContactListView: View {
    @StateObject private var viewModel: ContactListViewModel

    private let repository: ChatRepository
    private let myUserUuid: String?

    @State private var showAdd = false
    @State private var newUsername = ""
    @State private var openedChat: ChatResponse?
    @State private var isOpening = false
    @State private var presenceTask: Task<Void, Never>?

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: ContactListViewModel(repository: container.chatRepository))
        repository = container.chatRepository
        myUserUuid = JWT.subject(from: container.tokenStore.chatToken)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.contacts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2").font(.largeTitle).foregroundColor(.secondary)
                        Text(viewModel.error ?? "Нет контактов").foregroundColor(.secondary)
                    }
                } else {
                    List(viewModel.contacts) { contact in
                        Button {
                            openChat(contact)
                        } label: {
                            ContactRow(contact: contact)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Контакты")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { newUsername = ""; showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .refreshable { await viewModel.load() }
            .alert("Добавить контакт", isPresented: $showAdd) {
                TextField("Имя пользователя", text: $newUsername)
                    .textInputAutocapitalization(.never)
                Button("Добавить") {
                    let name = newUsername
                    Task { _ = await viewModel.add(username: name) }
                }
                Button("Отмена", role: .cancel) {}
            }
            .navigationDestination(isPresented: Binding(
                get: { openedChat != nil },
                set: { if !$0 { openedChat = nil } }
            )) {
                if let openedChat {
                    ChatConversationView(chat: openedChat, repository: repository, myUserUuid: myUserUuid)
                }
            }
        }
        .task { await viewModel.load() }
        // Опрос статусов, пока экран на переднем плане: на возврате на экран
        // первый запрос уходит сразу, в фоне цикл снимается.
        .onAppear {
            guard presenceTask == nil else { return }
            presenceTask = Task {
                await viewModel.refreshPresence()
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: Config.presencePollInterval)
                    if Task.isCancelled { break }
                    await viewModel.refreshPresence()
                }
            }
        }
        .onDisappear {
            presenceTask?.cancel()
            presenceTask = nil
        }
    }

    private func openChat(_ contact: ContactResponse) {
        guard !isOpening else { return }
        isOpening = true
        Task {
            openedChat = await viewModel.openChat(with: contact)
            isOpening = false
        }
    }
}

struct ContactRow: View {
    let contact: ContactResponse

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: ImageURL.chat(contact.avatarUrl), size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.displayName).font(.headline)
                Text(contact.username ?? "").font(.subheadline).foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                // Точка нужна только рядом с «в сети»: у офлайна подпись уже
                // несёт время последнего визита.
                if contact.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(contact.isOnline ? .green : .secondary)
            }
        }
    }

    private var statusText: String {
        contact.isOnline
            ? LastSeenFormatter.onlineText
            : LastSeenFormatter.label(lastSeenAt: contact.lastSeenAt)
    }
}
