import Foundation

/// Реализация `AuthRepositoryProtocol` на едином IdP (`auth.muzea.su`).
///
/// Вход passwordless: регистрация → код на email → verify-email; повторный вход
/// → otp/request → otp/verify. Успешная проверка кода сразу возвращает пару
/// access+refresh, которую сохраняем в Keychain.
final class AuthRepositoryImpl: AuthRepositoryProtocol {
    private let client: HTTPClient
    private let store: TokenStore

    init(client: HTTPClient, store: TokenStore) {
        self.client = client
        self.store = store
    }

    var isLoggedIn: Bool {
        !(store.token ?? "").isEmpty
    }

    func register(email: String, username: String, displayName: String?) async throws {
        let _: AuthServiceMessage = try await client.request(
            "POST",
            "/auth/register",
            body: AuthRegisterRequest(
                email: email,
                username: username,
                displayName: displayName?.isEmpty == true ? nil : displayName
            ),
            authorized: false
        )
    }

    func verifyEmail(email: String, code: String) async throws {
        let response: AuthTokenResponse = try await client.request(
            "POST",
            "/auth/verify-email",
            body: AuthVerifyEmailRequest(email: email, code: code, deviceId: store.deviceId),
            authorized: false
        )
        persist(response)
    }

    func resendVerification(email: String) async throws {
        let _: AuthServiceMessage = try await client.request(
            "POST",
            "/auth/resend-verification",
            body: AuthEmailRequest(email: email),
            authorized: false
        )
    }

    func requestLoginCode(email: String) async throws -> LoginCodeStatus {
        let response: AuthOtpRequestResponse = try await client.request(
            "POST",
            "/auth/otp/request",
            body: AuthEmailRequest(email: email),
            authorized: false
        )
        return response.loginCodeStatus
    }

    func verifyLoginCode(email: String, code: String) async throws {
        let response: AuthTokenResponse = try await client.request(
            "POST",
            "/auth/otp/verify",
            body: AuthOtpVerifyRequest(
                email: email,
                code: code,
                deviceId: store.deviceId,
                deviceName: store.deviceName
            ),
            authorized: false
        )
        persist(response)
    }

    func currentUser() async throws -> AuthServiceUser {
        try await client.request("GET", "/auth/me")
    }

    func deleteAccount() async throws {
        try await client.requestVoid("DELETE", "/auth/me")
    }

    /// Локальный выход: сначала чистим токены (UI сразу уходит на логин), затем
    /// best-effort отзываем refresh-сессию. Access-токен живёт до 15 минут, но
    /// refresh уже не восстановит сессию.
    func logout() async {
        let refreshToken = store.refreshToken
        store.clearSession()
        guard let refreshToken, !refreshToken.isEmpty else { return }
        _ = try? await client.requestVoid(
            "POST",
            "/auth/logout",
            body: AuthLogoutRequest(refreshToken: refreshToken),
            authorized: false
        )
    }

    func clearLocalSession() {
        store.clearSession()
    }

    private func persist(_ response: AuthTokenResponse) {
        store.token = response.accessToken
        store.refreshToken = response.refreshToken
        if let user = response.user {
            if let username = user.username { store.username = username }
            if let email = user.email { store.email = email }
        }
    }
}
