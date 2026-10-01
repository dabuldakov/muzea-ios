import Foundation

@MainActor
final class ContactListViewModel: ObservableObject {
    @Published var contacts: [ContactResponse] = []
    @Published var isLoading = false
    @Published var error: String?

    private let repository: ChatRepository

    init(repository: ChatRepository) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            contacts = try await repository.loadContacts()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func add(username: String) async -> Bool {
        do {
            _ = try await repository.addContact(username: username)
            await load()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Обновляет только статусы, не трогая состав и порядок списка: сервер
    /// присылает присутствие отдельным лёгким запросом, а не перезагрузкой
    /// `/api/contacts`. Пустой ответ — сбой сети, а не «все офлайн», поэтому
    /// список не переписываем.
    func refreshPresence() async {
        let uuids = contacts.compactMap { $0.contactUserUuid }
        guard !uuids.isEmpty else { return }

        let presence = await repository.loadPresence(userUuids: uuids)
        guard !presence.isEmpty else { return }

        contacts = contacts.map { contact in
            guard let uuid = contact.contactUserUuid, let fresh = presence[uuid] else {
                return contact
            }
            return contact.replacingPresence(online: fresh.online, lastSeenAt: fresh.lastSeenAt)
        }
    }

    func openChat(with contact: ContactResponse) async -> ChatResponse? {
        guard let uuid = contact.contactUserUuid, !uuid.isEmpty else {
            error = "У контакта нет UUID"
            return nil
        }
        do {
            return try await repository.createPrivateChat(userUuid: uuid)
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
}
