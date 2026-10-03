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

/// Единое состояние экрана профиля.
struct ProfileUiState {
    var user: UserResponse?
    var avatarUrl: String?
    var isLoading = false
    var isBusy = false
    var error: String?
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var state = ProfileUiState()

    private let userRepository: UserRepository
    private let avatarRepository: AvatarRepository
    private let chatSessionRepository: ChatSessionRepository

    init(
        userRepository: UserRepository,
        avatarRepository: AvatarRepository,
        chatSessionRepository: ChatSessionRepository,
        initialUser: UserResponse? = nil
    ) {
        self.userRepository = userRepository
        self.avatarRepository = avatarRepository
        self.chatSessionRepository = chatSessionRepository
        state.user = initialUser
    }

    func load() async {
        state.isLoading = true
        do {
            state.user = try await userRepository.currentUser()
            state.error = nil
        } catch {
            state.error = error.localizedDescription
        }
        state.isLoading = false
        if let avatar = try? await avatarRepository.loadAvatar() {
            state.avatarUrl = avatar
        }
    }

    func update(fullName: String, email: String) async -> Bool {
        guard let id = state.user?.id else { return false }
        do {
            state.user = try await userRepository.updateUser(id: id, fullName: fullName, email: email)
            return true
        } catch {
            state.error = error.localizedDescription
            return false
        }
    }

    func uploadAvatar(data: Data, fileName: String, mimeType: String) async {
        state.isBusy = true
        do {
            state.avatarUrl = try await avatarRepository.uploadAvatar(
                data: data,
                fileName: fileName,
                mimeType: mimeType
            )
            state.error = nil
        } catch {
            state.error = error.localizedDescription
        }
        state.isBusy = false
    }

    func deleteAvatar() async {
        state.isBusy = true
        do {
            try await avatarRepository.deleteAvatar()
            state.avatarUrl = nil
            state.error = nil
        } catch {
            state.error = error.localizedDescription
        }
        state.isBusy = false
    }

    /// Удаление аккаунта: сначала чат-сервер (сообщения, контакты, вложения,
    /// FCM-токены), затем основной (новости, видео, профиль).
    ///
    /// Локальное хранилище и согласие на обработку персональных данных чистит
    /// вызывающая сторона только когда оба сервера подтвердили удаление — иначе
    /// пользователь потерял бы пароль и не смог повторить попытку.
    func deleteAccount() async -> DeleteAccountOutcome {
        state.isBusy = true
        defer { state.isBusy = false }

        let chatErased: Bool
        do {
            try await chatSessionRepository.deleteAccount()
            chatErased = true
        } catch {
            chatErased = false
        }

        guard let id = state.user?.id else {
            return chatErased ? .chatFailed : .failed("Не удалось загрузить профиль. Попробуйте позже.")
        }

        do {
            try await userRepository.deleteAccount(id: id)
        } catch {
            return .failed(Legal.deleteFailedMessage())
        }

        return chatErased ? .deleted : .chatFailed
    }

    func reportValidationError(_ message: String) {
        state.error = message
    }

    func consumeError() {
        state.error = nil
    }
}
