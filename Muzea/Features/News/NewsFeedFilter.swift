import Foundation

enum NewsFeedFilter {
    /// Оставляет новости авторов из контактов и свои собственные.
    /// Регистрозависимо, значения обрезаются от пробелов.
    static func filter(
        _ news: [NewsResponse],
        contactUsernames: Set<String>,
        ownUsername: String?
    ) -> [NewsResponse] {
        let contacts = Set(
            contactUsernames
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
        let me = ownUsername?.trimmingCharacters(in: .whitespaces)
        let hasMe = !(me ?? "").isEmpty

        if contacts.isEmpty && !hasMe { return [] }

        return news.filter { item in
            let author = item.author.trimmingCharacters(in: .whitespaces)
            return contacts.contains(author) || (hasMe && author == me)
        }
    }
}
