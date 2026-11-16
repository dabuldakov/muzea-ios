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
            return "Сессия истекла. Войдите снова."
        case .transport:
            return "Нет подключения к серверу."
        case .invalidURL:
            return "Некорректный адрес запроса."
        case .decoding:
            return "Сервер вернул неожиданный ответ."
        case .server(let status, let body):
            if let data = body.data(using: .utf8),
               let parsed = try? JSONDecoder().decode(AuthServiceErrorBody.self, from: data) {
                return localize(code: parsed.code, fallback: parsed.message, status: status)
            }
            if status == 403 {
                return "Требуется авторизация."
            }
            return "Ошибка сервера (\(status))."
        }
    }

    static func localize(code: String?, fallback: String?, status: Int) -> String {
        switch code {
        case "otp_invalid": return "Неверный код."
        case "otp_expired": return "Код истёк. Запросите новый."
        case "otp_not_found": return "Код не найден. Запросите новый."
        case "otp_attempts_exceeded": return "Слишком много попыток. Запросите новый код."
        case "otp_cooldown", "ip_cooldown": return "Подождите немного перед повторной отправкой."
        case "otp_hourly_limit", "ip_rate_limit": return "Слишком много запросов. Попробуйте позже."
        case "email_taken": return "Этот email уже зарегистрирован."
        case "username_taken": return "Это имя пользователя уже занято."
        case "user_not_found": return "Пользователь не найден."
        case "invalid_refresh_token", "refresh_token_reused", "refresh_token_expired":
            return "Сессия истекла. Войдите снова."
        case "validation_error":
            return fallback ?? "Проверьте введённые данные."
        default:
            if status == 429 { return fallback ?? "Слишком много запросов. Попробуйте позже." }
            return fallback ?? "Ошибка сервера (\(status))."
        }
    }
}
