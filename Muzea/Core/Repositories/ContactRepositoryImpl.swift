import Foundation

/// Реализация `ContactRepository`: контакты и пакетное присутствие.
final class ContactRepositoryImpl: ContactRepository {
    private let auth: ChatAuthorization

    init(auth: ChatAuthorization) {
        self.auth = auth
    }

    func loadContacts() async throws -> [ContactResponse] {
        try await auth.authorized {
            try await auth.client.request("GET", "/api/contacts")
        }
    }

    /// Добавление контакта по username: сначала резолвим username → userUuid,
    /// затем POST-им контакт. Двумя шагами, потому что сервер адресует контакты
    /// по UUID, а пользователь вводит логин.
    func addContact(username: String) async throws -> ContactResponse {
        let user: ChatUserResponse = try await auth.authorized {
            try await auth.client.request("GET", "/api/users/by-username/\(username)")
        }
        return try await auth.authorized {
            try await auth.client.request(
                "POST",
                "/api/contacts",
                body: AddContactRequest(contactUserUuid: user.userUuid, contactName: nil)
            )
        }
    }

    /// Пакетный статус присутствия по UUID.
    ///
    /// Сервер ограничивает размер пачки, поэтому список режется на чанки, а
    /// ответы склеиваются: иначе запрос на 300 контактов упал бы с 400. Пустой
    /// вход возвращает пустой результат без обращения к сети. Ошибка отдельного
    /// чанка не срывает остальные — частичный результат лучше пустого.
    func loadPresence(userUuids: [String]) async -> [String: PresenceResponse] {
        var seen = Set<String>()
        let wanted = userUuids.filter {
            let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && seen.insert(trimmed).inserted
        }
        guard !wanted.isEmpty else { return [:] }

        var result: [String: PresenceResponse] = [:]
        for chunk in stride(from: 0, to: wanted.count, by: Config.presenceBatchSize) {
            let end = min(chunk + Config.presenceBatchSize, wanted.count)
            let slice = Array(wanted[chunk..<end])
            do {
                let presence: [PresenceResponse] = try await auth.authorized {
                    try await auth.client.request(
                        "GET",
                        "/api/presence",
                        query: slice.map { URLQueryItem(name: "userUuids", value: $0) }
                    )
                }
                for item in presence { result[item.userUuid] = item }
            } catch {
                // Пропускаем чанк: остальные контакты всё равно обновятся.
            }
        }
        return result
    }
}
