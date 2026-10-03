import Foundation

@MainActor
final class CreateGroupViewModel: ObservableObject {
    @Published private(set) var contacts: [ContactResponse] = []
    @Published private(set) var isLoadingContacts = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var error: String?

    private let chatRepository: ChatRepository
    private let contactRepository: ContactRepository

    init(chatRepository: ChatRepository, contactRepository: ContactRepository) {
        self.chatRepository = chatRepository
        self.contactRepository = contactRepository
    }

    func loadContacts() async {
        isLoadingContacts = true
        contacts = (try? await contactRepository.loadContacts()) ?? []
        isLoadingContacts = false
    }

    func create(title: String, memberUuids: [String]) async -> ChatResponse? {
        let name = title.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            error = nil
            return try await chatRepository.createGroupChat(title: name, memberUuids: memberUuids)
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func consumeError() {
        error = nil
    }
}
