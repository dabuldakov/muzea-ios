import Foundation

enum AuthPhase: Equatable {
    case email
    case code
}

enum AuthFlow: Equatable {
    case login
    case register
}

/// Единое состояние экранов входа/регистрации.
struct AuthUiState: Equatable {
    var isLoading = false
    var error: String?
    var info: String?
    var phase: AuthPhase = .email
    var flow: AuthFlow = .login
    var email = ""
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var state = AuthUiState()

    private let repository: AuthRepositoryProtocol

    init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Login

    func requestLoginCode(email: String) async -> Bool {
        let normalized = Self.normalizeEmail(email)
        guard Self.isValidEmail(normalized) else {
            state.error = "Введите корректный email."
            return false
        }
        state.flow = .login
        state.email = normalized
        return await perform {
            try await repository.requestLoginCode(email: normalized)
        } onSuccess: {
            state.phase = .code
            state.info = "Код отправлен на \(normalized)."
        }
    }

    // MARK: - Register

    func register(email: String, username: String, displayName: String) async -> Bool {
        let normalizedEmail = Self.normalizeEmail(email)
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidEmail(normalizedEmail) else {
            state.error = "Введите корректный email."
            return false
        }
        guard Self.isValidUsername(normalizedUsername) else {
            state.error = "Имя пользователя: 3–64 символа, только латиница, цифры, «_» и «.»."
            return false
        }
        state.flow = .register
        state.email = normalizedEmail
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return await perform {
            try await repository.register(
                email: normalizedEmail,
                username: normalizedUsername,
                displayName: name.isEmpty ? nil : name
            )
        } onSuccess: {
            state.phase = .code
            state.info = "Код подтверждения отправлен на \(normalizedEmail)."
        }
    }

    // MARK: - Code

    func verify(code: String) async -> Bool {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty else {
            state.error = "Введите код из письма."
            return false
        }
        let flow = state.flow
        let email = state.email
        return await perform {
            switch flow {
            case .login:
                try await repository.verifyLoginCode(email: email, code: normalizedCode)
            case .register:
                try await repository.verifyEmail(email: email, code: normalizedCode)
            }
        } onSuccess: {
            state.info = nil
        }
    }

    func resend() async -> Bool {
        let flow = state.flow
        let email = state.email
        return await perform {
            switch flow {
            case .login:
                try await repository.requestLoginCode(email: email)
            case .register:
                try await repository.resendVerification(email: email)
            }
        } onSuccess: {
            state.info = "Код отправлен повторно на \(email)."
        }
    }

    func backToEmail() {
        state.phase = .email
        state.error = nil
        state.info = nil
    }

    func consumeError() {
        state.error = nil
    }

    // MARK: - Validation

    static func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isValidEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return false }
        let host = parts[1]
        return host.contains(".") && !host.hasPrefix(".") && !host.hasSuffix(".")
    }

    static func isValidUsername(_ username: String) -> Bool {
        guard (3...64).contains(username.count) else { return false }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.")
        return username.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    // MARK: - Private

    private func perform(
        _ action: () async throws -> Void,
        onSuccess: () -> Void
    ) async -> Bool {
        state.isLoading = true
        state.error = nil
        do {
            try await action()
            state.isLoading = false
            onSuccess()
            return true
        } catch {
            state.isLoading = false
            state.error = AuthErrorMapper.message(for: error)
            return false
        }
    }
}
