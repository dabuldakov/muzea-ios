import SwiftUI

struct ContactListView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: ContactListViewModel
    @StateObject private var router = Router()

    @State private var showAdd = false
    @State private var newUsername = ""
    @State private var presenceTask: Task<Void, Never>?

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: ContactListViewModel(
            repository: container.contactRepository,
            openPrivateChat: container.openPrivateChat
        ))
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            content
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
                .navigationDestination(for: Route.self) { RouteDestinationView(route: $0) }
        }
        .environmentObject(router)
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

    @ViewBuilder
    private var content: some View {
        if viewModel.state.contacts.isEmpty {
            if viewModel.state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.2").font(.largeTitle).foregroundColor(.secondary)
                    Text(viewModel.state.error ?? "Нет контактов")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        } else {
            List(viewModel.state.contacts) { contact in
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

    private func openChat(_ contact: ContactResponse) {
        Task {
            if let chat = await viewModel.openChat(with: contact) {
                router.push(.conversation(chat))
            }
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
