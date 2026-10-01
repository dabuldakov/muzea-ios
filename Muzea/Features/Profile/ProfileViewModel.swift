import Foundation

/// Результат удаления аккаунта: разные сообщения требуют разных действий в UI.
enum DeleteAccountOutcome: Equatable {
    /// Оба сервера подтвердили удаление, локальные данные и согласие очищены.
    case deleted
    /// Основной сервер удалён, чат-сервер ответил ошибкой — повторить позже.
    case chatFailed
    /// Основной сервер не подтвердил удаление.
    case failed(String)
}

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

    /// Удаление аккаунта: сначала чат-сервер (сообщения, контакты, вложения,
    /// FCM-токены), затем основной (новости, видео, профиль).
    ///
    /// Локальное хранилище и согласие на обработку персональных данных чистим
    /// только когда оба сервера подтвердили удаление — иначе пользователь потерял
    /// бы пароль и не смог повторить попытку.
    func deleteAccount() async -> DeleteAccountOutcome {
        isBusy = true
        defer { isBusy = false }

        let chatErased: Bool
        do {
            try await chatRepository.deleteAccount()
            chatErased = true
        } catch {
            chatErased = false
        }

        guard let id = user?.id else {
            return chatErased ? .chatFailed : .failed("Не удалось загрузить профиль. Попробуйте позже.")
        }

        do {
            try await authRepository.deleteAccount(id: id)
        } catch {
            return .failed(Legal.deleteFailedMessage())
        }

        return chatErased ? .deleted : .chatFailed
    }
}
