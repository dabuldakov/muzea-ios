import Foundation

/// Форматирует время, присланное сервером, в локальный часовой пояс устройства.
///
/// Серверы хранят дату/время как LocalDateTime без смещения (таймзона контейнера
/// = UTC, а время пишется в UTC), поэтому строку без зоны трактуем как UTC.
/// Используется как аналог Android `LocalTimeFormatter`.
enum DateTimeFormat {
    private static let serverPattern = "yyyy-MM-dd'T'HH:mm:ss"
    private static let dateTimePattern = "yyyy-MM-dd HH:mm"
    private static let datePattern = "yyyy-MM-dd"

    /// Полное время, например «2026-09-22 12:00» в поясе устройства.
    static func full(_ iso: String?) -> String { format(iso, pattern: dateTimePattern) }

    /// Только дата, например «2026-09-22» в поясе устройства.
    static func date(_ iso: String?) -> String { format(iso, pattern: datePattern) }

    private static func format(_ iso: String?, pattern: String) -> String {
        guard let iso, !iso.isEmpty else { return "" }
        let clipped = iso.count >= 19 ? String(iso.prefix(19)) : iso

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = serverPattern

        guard let date = parser.date(from: clipped) else { return iso }

        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.timeZone = .current
        output.dateFormat = pattern
        return output.string(from: date)
    }
}
