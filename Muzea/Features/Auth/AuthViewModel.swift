import Foundation

/// Единое состояние экранов входа/регистрации.
struct AuthUiState: Equatable {
    var isLoading = false
    var error: String?
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var state = AuthUiState()

    private let repository: AuthRepositoryProtocol

    init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    func login(username: String, password: String) async -> Bool {
        await run { try await repository.login(username: username, password: password) }
    }

    func register(username: String, email: String, password: String, fullName: String) async -> Bool {
        await run {
            try await repository.register(
                username: username,
                email: email,
                password: password,
                fullName: fullName
            )
        }
    }

    func logout() {
        repository.logout()
    }

    func consumeError() {
        state.error = nil
    }

    @discardableResult
    private func run(_ action: () async throws -> AuthResponse) async -> Bool {
        state = AuthUiState(isLoading: true, error: nil)
        do {
            _ = try await action()
            state = AuthUiState(isLoading: false)
            return true
        } catch {
            state = AuthUiState(isLoading: false, error: error.localizedDescription)
            return false
        }
    }
}
