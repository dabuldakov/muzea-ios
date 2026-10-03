import Foundation

/// Единое состояние списка контактов.
struct ContactListUiState: Equatable {
    var contacts: [ContactResponse] = []
    var isLoading = false
    var error: String?
}

@MainActor
final class ContactListViewModel: ObservableObject {
    @Published private(set) var state = ContactListUiState()
    @Published private(set) var isOpeningChat = false

    private let repository: ContactRepository
    private let openPrivateChat: OpenPrivateChatUseCase

    init(repository: ContactRepository, openPrivateChat: OpenPrivateChatUseCase) {
        self.repository = repository
        self.openPrivateChat = openPrivateChat
    }

    func load() async {
        state.isLoading = state.contacts.isEmpty
        do {
            state.contacts = try await repository.loadContacts()
            state.error = nil
        } catch {
            state.error = error.localizedDescription
        }
        state.isLoading = false
    }

    func add(username: String) async -> Bool {
        do {
            _ = try await repository.addContact(username: username)
            await load()
            return true
        } catch {
            state.error = error.localizedDescription
            return false
        }
    }

    /// Обновляет только статусы, не трогая состав и порядок списка: сервер
    /// присылает присутствие отдельным лёгким запросом, а не перезагрузкой
    /// `/api/contacts`. Пустой ответ — сбой сети, а не «все офлайн».
    func refreshPresence() async {
        let uuids = state.contacts.compactMap { $0.contactUserUuid }
        guard !uuids.isEmpty else { return }

        let presence = await repository.loadPresence(userUuids: uuids)
        guard !presence.isEmpty else { return }

        state.contacts = state.contacts.map { contact in
            guard let uuid = contact.contactUserUuid, let fresh = presence[uuid] else {
                return contact
            }
            return contact.replacingPresence(online: fresh.online, lastSeenAt: fresh.lastSeenAt)
        }
    }

    /// Открывает существующую переписку или создаёт новую через use-case:
    /// повторный тап по контакту больше не плодит дубликаты чатов.
    func openChat(with contact: ContactResponse) async -> ChatResponse? {
        guard let uuid = contact.contactUserUuid, !uuid.isEmpty else {
            state.error = "У контакта нет UUID"
            return nil
        }
        guard !isOpeningChat else { return nil }
        isOpeningChat = true
        defer { isOpeningChat = false }
        do {
            return try await openPrivateChat(userUuid: uuid)
        } catch {
            state.error = error.localizedDescription
            return nil
        }
    }

    func consumeError() {
        state.error = nil
    }
}
