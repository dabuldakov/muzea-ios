import Foundation

/// Разбирает `lastSeenAt` из ответов сервера и строит подпись «был(а) N назад».
///
/// Сервер отдаёт LocalDateTime в UTC — либо с суффиксом `Z`, либо без зоны.
/// Строку без зоны трактуем как UTC, как и `DateTimeFormat`. Аналог Android
/// `LastSeenFormatter`.
enum LastSeenFormatter {
    private static let serverPattern = "yyyy-MM-dd'T'HH:mm:ss"

    /// Текст статуса «в сети» (Android `presence_online`).
    static var onlineText: String { L10n.presenceOnline }
    /// Без данных о последнем визите (Android `presence_offline`).
    static var offlineText: String { L10n.presenceOffline }

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
            return L10n.presenceJustNow
        case ..<60:
            return L10n.presenceMinutes(Int(minutes))
        case ..<(24 * 60):
            return L10n.presenceHours(Int(minutes / 60))
        default:
            return L10n.presenceLastSeen(DateTimeFormat.full(iso, timeZone: timeZone))
        }
    }
}
