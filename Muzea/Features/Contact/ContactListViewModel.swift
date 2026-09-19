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
