import Foundation

/// Одна запись диагностики. Формат совпадает с Android `ErrorEvent`
/// и JSON бэкенда `/api/telemetry/errors`.
struct ErrorEvent: Codable, Equatable {
    let eventId: String
    let time: String
    let level: String
    let tag: String?
    let message: String?
    let stack: String?
    let appVersion: String
    let versionCode: Int
    let buildType: String
    let device: String
    let os: String
    let userId: String?

    init(
        eventId: String = UUID().uuidString,
        time: String = ErrorEvent.timestamp(),
        level: String,
        tag: String?,
        message: String?,
        stack: String?,
        appVersion: String,
        versionCode: Int,
        buildType: String,
        device: String,
        os: String,
        userId: String?
    ) {
        self.eventId = eventId
        self.time = time
        self.level = level
        self.tag = tag
        self.message = message
        self.stack = stack
        self.appVersion = appVersion
        self.versionCode = versionCode
        self.buildType = buildType
        self.device = device
        self.os = os
        self.userId = userId
    }

    static func timestamp(_ date: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}

struct ErrorReportRequest: Encodable {
    let events: [ErrorEvent]
    let overflowed: Bool
}

struct ErrorReportResponse: Decodable {
    let accepted: Int?
}

/// Чистит почту, телефоны и токены перед сохранением и отправкой.
/// Повторяет Android `ErrorSanitizer`.
enum ErrorSanitizer {
    private static let email = try! NSRegularExpression(
        pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
    )
    private static let phone = try! NSRegularExpression(
        pattern: #"(?<!\d)(?:\+7|8)[\s(-]*\d{3}[\s)-]*\d{3}[\s-]*\d{2}[\s-]*\d{2}(?!\d)"#
    )
    private static let bearer = try! NSRegularExpression(
        pattern: #"(?i)bearer\s+[A-Za-z0-9._\-]+"#
    )
    private static let jwt = try! NSRegularExpression(
        pattern: #"[A-Za-z0-9_\-]{16,}\.[A-Za-z0-9_\-]{16,}\.[A-Za-z0-9_\-]{16,}"#
    )
    private static let longToken = try! NSRegularExpression(
        pattern: #"(?i)(token|password|secret|api[_-]?key)\s*[=:]\s*[^\s,;"']+"#
    )

    static func sanitize(_ text: String) -> String {
        var result = text
        result = replace(email, in: result, with: "[email]")
        result = replace(phone, in: result, with: "[phone]")
        result = replace(bearer, in: result, with: "Bearer [token]")
        result = replace(jwt, in: result, with: "[token]")
        result = longToken.stringByReplacingMatches(
            in: result,
            range: NSRange(result.startIndex..., in: result),
            withTemplate: "$1=[hidden]"
        )
        return result
    }

    private static func replace(
        _ regex: NSRegularExpression,
        in text: String,
        with template: String
    ) -> String {
        regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )
    }
}
