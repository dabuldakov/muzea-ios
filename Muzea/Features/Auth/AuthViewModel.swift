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
            state.error = L10n.emailInvalid
            return false
        }
        state.flow = .login
        state.email = normalized
        return await submitLoginCodeRequest(email: normalized)
    }

    /// Общий путь для «Получить код» и «Отправить ещё раз». Сервер сообщает,
    /// существует ли аккаунт: без этого пользователь видел «код отправлен»,
    /// хотя письмо не уходило. Неподтверждённый email сразу доводим до кода.
    private func submitLoginCodeRequest(email: String) async -> Bool {
        state.isLoading = true
        state.error = nil
        defer { state.isLoading = false }
        do {
            let status = try await repository.requestLoginCode(email: email)
            switch status {
            case .sent, .unknown:
                state.phase = .code
                state.info = L10n.codeSent(email)
                return true
            case .notFound:
                state.phase = .email
                state.info = nil
                state.error = L10n.emailNotRegistered
                return false
            case .deleted:
                state.phase = .email
                state.info = nil
                state.error = L10n.accountDeactivated
                return false
            case .unverified:
                try await repository.resendVerification(email: email)
                state.flow = .register
                state.phase = .code
                state.info = L10n.verificationSent(email)
                return true
            }
        } catch {
            state.error = AuthErrorMapper.message(for: error)
            return false
        }
    }

    // MARK: - Register

    func register(email: String, username: String, displayName: String) async -> Bool {
        let normalizedEmail = Self.normalizeEmail(email)
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidEmail(normalizedEmail) else {
            state.error = L10n.emailInvalid
            return false
        }
        guard Self.isValidUsername(normalizedUsername) else {
            state.error = L10n.usernameInvalid
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
            state.info = L10n.codeSent(normalizedEmail)
        }
    }

    // MARK: - Code

    func verify(code: String) async -> Bool {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty else {
            state.error = L10n.codeRequired
            return false
        }
        guard normalizedCode.count >= 4 else {
            state.error = L10n.codeTooShort
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
        if flow == .login {
            return await submitLoginCodeRequest(email: email)
        }
        return await perform {
            try await repository.resendVerification(email: email)
        } onSuccess: {
            state.info = L10n.codeSentAgain(email)
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

    /// Невидимые символы, которые прилетают с клавиатуры/вставки и ломают
    /// поиск пользователя на сервере (он отвечает нейтрально, письмо не уходит).
    private static let zeroWidthCharacters = CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}")

    nonisolated static func normalizeEmail(_ email: String) -> String {
        let cleaned = email.unicodeScalars.filter {
            !zeroWidthCharacters.contains($0)
        }
        return String(String.UnicodeScalarView(cleaned))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// Та же строгость, что у `android.util.Patterns.EMAIL_ADDRESS`: только
    /// ASCII, без пробелов внутри, с доменом и TLD. Мягкая проверка пропускала
    /// адрес с пробелом и сервер молча не отправлял код.
    nonisolated static func isValidEmail(_ email: String) -> Bool {
        guard email.unicodeScalars.allSatisfy({ $0.isASCII }) else { return false }
        guard !email.contains(where: \.isWhitespace) else { return false }
        let pattern = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$"
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    nonisolated static func isValidUsername(_ username: String) -> Bool {
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
            ErrorReporter.logCaught("Auth", error)
            return false
        }
    }
}
