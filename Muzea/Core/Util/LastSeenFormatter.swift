import Foundation

/// Разбирает `lastSeenAt` из ответов сервера и строит подпись «был(а) N назад».
///
/// Сервер отдаёт LocalDateTime в UTC — либо с суффиксом `Z`, либо без зоны.
/// Строку без зоны трактуем как UTC, как и `DateTimeFormat`. Аналог Android
/// `LastSeenFormatter`.
enum LastSeenFormatter {
    private static let serverPattern = "yyyy-MM-dd'T'HH:mm:ss"

    /// Текст статуса «в сети» (Android `presence_online`).
    static let onlineText = "в сети"
    /// Без данных о последнем визите (Android `presence_offline`).
    static let offlineText = "офлайн"

    /// Момент последней активности либо nil, если данных нет.
    ///
    /// nil и «очень давно» — разные вещи: nil значит, что пользователь ещё не
    /// заходил, и «был(а) N назад» показывать нельзя.
    static func parse(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        let clipped = iso.count >= 19 ? String(iso.prefix(19)) : iso

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = serverPattern
        return parser.date(from: clipped)
    }

    /// Возраст в целых минутах (округление вниз). Отрицательные значения
    /// (рассинхрон часов) схлопываются в ноль, чтобы не показывать «через -2 мин».
    static func minutesAgo(_ iso: String?, now: Date = Date()) -> Int64? {
        guard let seenAt = parse(iso) else { return nil }
        let diff = now.timeIntervalSince(seenAt)
        if diff <= 0 { return 0 }
        return Int64(diff / 60)
    }

    /// Подпись последнего визита для офлайнового контакта.
    static func label(lastSeenAt iso: String?, now: Date = Date(), timeZone: TimeZone = .current) -> String {
        guard let minutes = minutesAgo(iso, now: now) else { return offlineText }
        switch minutes {
        case ..<1:
            return "был(а) только что"
        case ..<60:
            return "был(а) \(minutes) мин назад"
        case ..<(24 * 60):
            return "был(а) \(minutes / 60) ч назад"
        default:
            return "был(а) в сети \(DateTimeFormat.full(iso, timeZone: timeZone))"
        }
    }
}
