import Foundation

/// Результат удаления аккаунта: разные сообщения требуют разных действий в UI.
enum DeleteAccountOutcome: Equatable {
    /// Все серверы подтвердили деактивацию, локальные данные и согласие очищены.
    case deleted
    /// Профиль и IdP деактивированы, chat-сервер ответил ошибкой — повторить позже.
    case chatFailed
    /// Основной сервер или IdP не подтвердили деактивацию.
    case failed(String)
}

/// Единое состояние экрана профиля.
struct ProfileUiState {
    var user: UserResponse?
    /// Email живёт в auth-service, а не в makeup.
    var email: String?
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
    private let authRepository: AuthRepositoryProtocol

    init(
        userRepository: UserRepository,
        avatarRepository: AvatarRepository,
        chatSessionRepository: ChatSessionRepository,
        authRepository: AuthRepositoryProtocol,
        initialUser: UserResponse? = nil,
        initialEmail: String? = nil
    ) {
        self.userRepository = userRepository
        self.avatarRepository = avatarRepository
        self.chatSessionRepository = chatSessionRepository
        self.authRepository = authRepository
        state.user = initialUser
        state.email = initialEmail
    }

    func load() async {
        state.isLoading = true
        do {
            state.user = try await userRepository.currentUser()
            state.error = nil
        } catch {
            state.error = error.localizedDescription
        }
        if let authUser = try? await authRepository.currentUser() {
            state.email = authUser.email
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

    /// Деактивация аккаунта: chat (переписка/вложения/контакты) → makeup
    /// (новости/видео/профиль) → IdP (`/auth/me`). Данные не стираются: аккаунт
    /// закрывается, имя скрывается, вход блокируется до восстановления поддержкой.
    ///
    /// Локальное хранилище и согласие чистит вызывающая сторона только когда
    /// все серверы подтвердили деактивацию — иначе пользователь потерял бы сессию
    /// и не смог повторить попытку.
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

        do {
            try await authRepository.deleteAccount()
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
