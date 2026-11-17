import Foundation

// MARK: - auth.muzea.su DTOs

struct AuthRegisterRequest: Encodable {
    let email: String
    let username: String
    let displayName: String?
}

struct AuthVerifyEmailRequest: Encodable {
    let email: String
    let code: String
    let deviceId: String?
}

struct AuthEmailRequest: Encodable {
    let email: String
}

struct AuthOtpVerifyRequest: Encodable {
    let email: String
    let code: String
    let deviceId: String?
    let deviceName: String?
}

struct AuthRefreshRequest: Encodable {
    let refreshToken: String
    let deviceId: String?
}

struct AuthLogoutRequest: Encodable {
    let refreshToken: String
}

struct AuthServiceUser: Decodable, Equatable {
    let id: String?
    let email: String?
    let username: String?
    let displayName: String?
    let emailVerified: Bool?
}

struct AuthTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String?
    let expiresIn: Int64
    let user: AuthServiceUser?
}

struct AuthServiceMessage: Decodable {
    let message: String?
}

struct AuthServiceErrorBody: Decodable {
    let code: String?
    let message: String?
}

/// Локализация ошибок IdP по стабильному `code` из тела ответа.
enum AuthErrorMapper {
    static func message(for error: Error) -> String {
        guard let api = error as? APIError else {
            return error.localizedDescription
        }
        switch api {
        case .unauthorized:
            return L10n.sessionExpired
        case .transport:
            return L10n.networkUnavailable
        case .invalidURL:
            return L10n.invalidURL
        case .decoding:
            return L10n.unexpectedResponse
        case .server(let status, let body):
            if let data = body.data(using: .utf8),
               let parsed = try? JSONDecoder().decode(AuthServiceErrorBody.self, from: data) {
                return localize(code: parsed.code, fallback: parsed.message, status: status)
            }
            if status == 403 {
                return L10n.unauthorized
            }
            return L10n.serverCode(status)
        }
    }

    static func localize(code: String?, fallback: String?, status: Int) -> String {
        switch code {
        case "otp_invalid": return L10n.otpInvalid
        case "otp_expired": return L10n.otpExpired
        case "otp_not_found": return L10n.otpNotFound
        case "otp_attempts_exceeded": return L10n.otpAttempts
        case "otp_cooldown", "ip_cooldown": return L10n.cooldown
        case "otp_hourly_limit", "ip_rate_limit": return L10n.rateLimited
        case "email_taken": return L10n.emailTaken
        case "username_taken": return L10n.usernameTaken
        case "user_not_found": return L10n.userNotFound
        case "invalid_refresh_token", "refresh_token_reused", "refresh_token_expired":
            return L10n.sessionExpired
        case "validation_error":
            return fallback ?? L10n.checkInput
        default:
            if status == 429 { return fallback ?? L10n.rateLimited }
            return fallback ?? L10n.serverCode(status)
        }
    }
}
