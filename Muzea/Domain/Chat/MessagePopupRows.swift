import Foundation

/// Строка блока «Детали» в карточке действий над сообщением.
///
/// `status == nil` — это автор реакции, а не получатель: у такой строки нет
/// галочки доставки, только время реакции.
struct MessagePopupRow: Identifiable, Equatable {
    let id: String
    let name: String
    let avatarUrl: String?
    let status: MessageDeliveryStatus?
    let time: String
    let emojis: [String]
}

/// Собирает «кто прочитал» и «кто поставил реакции» для карточки действий.
/// Аналог Android `MessageDetailsRows` + `ReactionsByUser`: чистая логика,
/// которую можно покрыть тестами без UI.
enum MessagePopupRows {
    static let maxVisibleEmojis = 3

    static func build(
        message: ChatMessage,
        receipts: [ChatReceipt],
        statuses: [MessageStatus],
        myUserUuid: String?,
        youLabel: String,
        unknownLabel: String,
        formatTime: (String?) -> String
    ) -> [MessagePopupRow] {
        let emojisPerUser = emojisByUser(message)
        var seen = Set<String>()
        var rows: [MessagePopupRow] = []

        // Получатели: только у своих серверных сообщений и только вступившие
        // до сообщения — это уже учитывает MessageStatusCalculator.
        for participant in MessageStatusCalculator.participantStatuses(
            message: message,
            receipts: receipts,
            myUserUuid: myUserUuid
        ) {
            guard let uuid = participant.receipt.userUuid else { continue }
            let exact = statuses.first { $0.userUuid == uuid }
            // Как на Android: время берём только из отметки по этому
            // сообщению. Водяной знак квитанции — последнее прочтение чата,
            // для старого сообщения он дал бы неверную дату.
            let timestamp = participant.status == .read
                ? exact?.readAt
                : exact?.deliveredAt
            rows.append(MessagePopupRow(
                id: uuid,
                name: participant.receipt.displayName,
                avatarUrl: participant.receipt.avatarUrl,
                status: participant.status,
                time: formatTime(timestamp),
                emojis: emojisPerUser[uuid] ?? []
            ))
            seen.insert(uuid)
        }

        // Авторы реакций, которых нет среди получателей (например, чужие
        // сообщения: списка получателей у них нет).
        for author in reactionAuthors(message) where !seen.contains(author.uuid) {
            let receipt = receipts.first { $0.userUuid == author.uuid }
            rows.append(MessagePopupRow(
                id: author.uuid,
                name: author.uuid == myUserUuid
                    ? youLabel
                    : (receipt?.displayName ?? unknownLabel),
                avatarUrl: receipt?.avatarUrl,
                status: nil,
                time: formatTime(author.at),
                emojis: emojisPerUser[author.uuid] ?? []
            ))
            seen.insert(author.uuid)
        }

        return rows
    }

    /// Первые `limit` значков и сколько осталось за счётчиком «+N».
    static func visibleEmojis(
        _ emojis: [String],
        limit: Int = maxVisibleEmojis
    ) -> (shown: [String], hidden: Int) {
        guard emojis.count > limit else { return (emojis, 0) }
        return (Array(emojis.prefix(limit)), emojis.count - limit)
    }

    private static func emojisByUser(_ message: ChatMessage) -> [String: [String]] {
        var grouped: [String: [(at: String, emoji: String)]] = [:]
        for reaction in message.reactions ?? [] {
            for user in reaction.users ?? [] {
                guard let uuid = user.userUuid, !uuid.isEmpty else { continue }
                grouped[uuid, default: []].append((user.at ?? "", reaction.emoji))
            }
        }
        return grouped.mapValues { rows in
            rows.sorted { $0.at < $1.at }.map(\.emoji)
        }
    }

    private static func reactionAuthors(
        _ message: ChatMessage
    ) -> [(uuid: String, at: String?)] {
        var seen = Set<String>()
        var authors: [(uuid: String, at: String?)] = []
        for reaction in message.reactions ?? [] {
            for user in reaction.users ?? [] {
                guard let uuid = user.userUuid,
                      !uuid.isEmpty,
                      seen.insert(uuid).inserted else { continue }
                authors.append((uuid, user.at))
            }
        }
        return authors
    }
}
