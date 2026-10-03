import Foundation

/// Единое состояние экрана настроек группы (участники).
struct GroupSettingsUiState: Equatable {
    var participants: [ChatParticipantResponse] = []
    var isLoading = false
    var isUploading = false
    var error: String?
}

@MainActor
final class GroupSettingsViewModel: ObservableObject {
    @Published private(set) var state = GroupSettingsUiState()
    @Published private(set) var contacts: [ContactResponse] = []
    @Published private(set) var avatarUrl: String?

    let chatUuid: String
    let myUserUuid: String?

    private let chatRepository: ChatRepository
    private let contactRepository: ContactRepository
    private let avatarRepository: AvatarRepository
    private var uploadActive = false

    init(
        chatUuid: String,
        myUserUuid: String?,
        initialAvatarUrl: String?,
        chatRepository: ChatRepository,
        contactRepository: ContactRepository,
        avatarRepository: AvatarRepository
    ) {
        self.chatUuid = chatUuid
        self.myUserUuid = myUserUuid
        self.avatarUrl = initialAvatarUrl
        self.chatRepository = chatRepository
        self.contactRepository = contactRepository
        self.avatarRepository = avatarRepository
    }

    func load() async {
        state.isLoading = state.participants.isEmpty
        do {
            state.participants = try await chatRepository.loadChatParticipants(chatUuid: chatUuid)
            state.error = nil
        } catch {
            state.error = error.localizedDescription
        }
        state.isLoading = false
        contacts = (try? await contactRepository.loadContacts()) ?? []
    }

    func addMembers(_ memberUuids: [String]) async -> Bool {
        do {
            try await chatRepository.addGroupParticipants(chatUuid: chatUuid, memberUuids: memberUuids)
            await load()
            return true
        } catch {
            state.error = error.localizedDescription
            return false
        }
    }

    func uploadAvatar(data: Data, fileName: String, mimeType: String) async {
        guard !uploadActive else { return }
        uploadActive = true
        state.isUploading = true
        do {
            let path = try await avatarRepository.uploadChatAvatar(
                chatUuid: chatUuid,
                data: data,
                fileName: fileName,
                mimeType: mimeType
            )
            if let path, !path.isEmpty {
                avatarUrl = path
            }
            state.error = nil
        } catch {
            state.error = error.localizedDescription
        }
        state.isUploading = false
        uploadActive = false
    }

    func reportValidationError(_ message: String) {
        state.error = message
    }

    func consumeError() {
        state.error = nil
    }
}
