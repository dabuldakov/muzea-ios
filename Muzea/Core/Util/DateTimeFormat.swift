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
    static func full(_ iso: String?, timeZone: TimeZone = .current) -> String {
        format(iso, pattern: dateTimePattern, timeZone: timeZone)
    }

    /// Только дата, например «2026-09-22» в поясе устройства.
    static func date(_ iso: String?, timeZone: TimeZone = .current) -> String {
        format(iso, pattern: datePattern, timeZone: timeZone)
    }

    /// Только время, например «12:34» в поясе устройства.
    static func time(_ iso: String?, timeZone: TimeZone = .current) -> String {
        format(iso, pattern: "HH:mm", timeZone: timeZone)
    }

    private static func format(_ iso: String?, pattern: String, timeZone: TimeZone) -> String {
        guard let iso, !iso.isEmpty else { return "" }
        let clipped = iso.count >= 19 ? String(iso.prefix(19)) : iso

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = serverPattern

        guard let date = parser.date(from: clipped) else { return iso }

        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.timeZone = timeZone
        output.dateFormat = pattern
        return output.string(from: date)
    }
}

/// Компактный счётчик: 999, 1,2 тыс., 3,4 млн (как на Android).
enum CountFormat {
    static func short(_ value: Int64) -> String {
        let absValue = abs(value)
        if absValue < 1_000 { return "\(value)" }
        if absValue < 1_000_000 { return compact(value, divisor: 1_000, suffix: "K") }
        if absValue < 1_000_000_000 { return compact(value, divisor: 1_000_000, suffix: "M") }
        return compact(value, divisor: 1_000_000_000, suffix: "B")
    }

    private static func compact(_ value: Int64, divisor: Double, suffix: String) -> String {
        let scaled = Double(value) / divisor
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = abs(scaled) >= 10 ? 0 : 1
        formatter.minimumFractionDigits = 0
        return "\(formatter.string(from: NSNumber(value: scaled)) ?? "\(Int(scaled))") \(suffix)"
    }
}

