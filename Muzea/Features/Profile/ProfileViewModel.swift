import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var user: UserResponse?
    @Published var avatarUrl: String?
    @Published var error: String?
    @Published var isBusy = false

    private let authRepository: AuthRepository
    private let chatRepository: ChatRepository

    init(authRepository: AuthRepository, chatRepository: ChatRepository) {
        self.authRepository = authRepository
        self.chatRepository = chatRepository
    }

    func load() async {
        do {
            user = try await authRepository.currentUser()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        if let chatUser = try? await chatRepository.currentChatUser() {
            avatarUrl = chatUser.avatarUrl
        }
    }

    func update(fullName: String, email: String) async -> Bool {
        guard let id = user?.id else { return false }
        do {
            user = try await authRepository.updateUser(id: id, fullName: fullName, email: email)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func uploadAvatar(data: Data, fileName: String, mimeType: String) async {
        isBusy = true
        do {
            avatarUrl = try await chatRepository.uploadAvatar(data: data, fileName: fileName, mimeType: mimeType)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isBusy = false
    }

    func deleteAvatar() async {
        isBusy = true
        do {
            try await chatRepository.deleteAvatar()
            avatarUrl = nil
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isBusy = false
    }
}
