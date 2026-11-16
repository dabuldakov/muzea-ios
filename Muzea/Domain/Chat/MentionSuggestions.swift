import Foundation

/// Разбор `@`-упоминания в конце вводимого текста для подсказки участников.
///
/// Вынесено из View, чтобы поведение (границы слова, фильтр, лимит) покрывалось
/// обычными unit-тестами без UIKit.
enum MentionSuggestions {

    struct Query: Equatable {
        /// Индекс символа `@` в UTF-16 (как `NSRange` у TextField).
        let start: Int
        /// Позиция курсора.
        let end: Int
        /// Подходящие имена участников в порядке получения.
        let candidates: [String]
    }

    static func resolve(
        text: String,
        cursor: Int? = nil,
        usernames: [String],
        limit: Int = 6
    ) -> Query? {
        let nsText = text as NSString
        let position = min(max(cursor ?? nsText.length, 0), nsText.length)
        guard position > 0 else { return nil }

        let prefix = nsText.substring(to: position) as NSString
        let at = prefix.range(of: "@", options: .backwards).location
        guard at != NSNotFound else { return nil }
        // Упоминание только целиком: e-mail и «слово@слово» не подсказываем.
        if at > 0 {
            let before = prefix.substring(with: NSRange(location: at - 1, length: 1))
            if before.rangeOfCharacter(from: .whitespacesAndNewlines) == nil { return nil }
        }

        let query = prefix.substring(from: at + 1)
        if query.rangeOfCharacter(from: .whitespacesAndNewlines) != nil { return nil }

        var seen = Set<String>()
        var candidates: [String] = []
        for username in usernames where query.isEmpty
            || username.range(of: query, options: .caseInsensitive) != nil {
            let key = username.lowercased()
            if seen.insert(key).inserted {
                candidates.append(username)
            }
            if candidates.count == limit { break }
        }
        guard !candidates.isEmpty else { return nil }
        return Query(start: at, end: position, candidates: candidates)
    }

    /// Текст с заменой упоминания на выбранный ник и пробелом после него.
    static func apply(_ username: String, to text: String, query: Query) -> String {
        let nsText = text as NSString
        guard query.start >= 0, query.end <= nsText.length, query.start < query.end else {
            return text
        }
        let replacement = "@\(username) "
        return nsText.replacingCharacters(
            in: NSRange(location: query.start, length: query.end - query.start),
            with: replacement
        )
    }
}
