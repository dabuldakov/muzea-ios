import Foundation

/// Статус конкретного получателя для выбранного сообщения.
struct ParticipantDeliveryStatus: Equatable {
    let receipt: ChatReceipt
    let status: MessageDeliveryStatus
}

/// Расчёт галочек по водяным знакам участников.
///
/// Чистый объект: правила «доставлено/прочитано всеми» покрываются тестами без
/// ViewModel и сети. Водяные знаки сравниваются с `messageId`.
enum MessageStatusCalculator {

    static func statusOf(
        message: ChatMessage,
        receipts: [ChatReceipt],
        myUserUuid: String?,
        failedMessages: Set<String> = [],
        receiptsLoaded: Bool = true
    ) -> MessageDeliveryStatus? {
        guard message.isSent(by: myUserUuid) else { return nil }

        guard let messageId = message.messageId else {
            return failedMessages.contains(message.messageUuid) ? .failed : .sending
        }

        // Квитанции ещё не загружены: не показываем ложное «прочитано».
        guard receiptsLoaded else { return .sent }

        let recipients = receipts.filter {
            isRecipient($0, message: message, myUserUuid: myUserUuid)
        }
        if recipients.isEmpty {
            // Чат с самим собой: сообщение сразу считается прочитанным.
            return .read
        }

        let readByAll = recipients.allSatisfy { receipt in
            guard let lastRead = receipt.lastReadMessageId else { return false }
            return lastRead >= messageId
        }
        if readByAll { return .read }

        let deliveredToAll = recipients.allSatisfy { receipt in
            guard let lastDelivered = receipt.lastDeliveredMessageId else { return false }
            return lastDelivered >= messageId
        }
        if deliveredToAll { return .delivered }

        return .sent
    }

    /// Статусы всех своих сообщений: uuid -> галочка.
    static func statuses(
        messages: [ChatMessage],
        receipts: [ChatReceipt],
        myUserUuid: String?,
        failedMessages: Set<String> = [],
        receiptsLoaded: Bool = true
    ) -> [String: MessageDeliveryStatus] {
        var result: [String: MessageDeliveryStatus] = [:]
        for message in messages {
            if let status = statusOf(
                message: message,
                receipts: receipts,
                myUserUuid: myUserUuid,
                failedMessages: failedMessages,
                receiptsLoaded: receiptsLoaded
            ) {
                result[message.messageUuid] = status
            }
        }
        return result
    }

    /// Кто прочитал/получил конкретное сообщение — для экрана «Статус».
    /// Участники, вступившие после сообщения, не показываются.
    static func participantStatuses(
        message: ChatMessage,
        receipts: [ChatReceipt],
        myUserUuid: String?
    ) -> [ParticipantDeliveryStatus] {
        // «Кто прочитал» имеет смысл только для своих сообщений: у чужих
        // получателей нет, а список участников вводил бы в заблуждение.
        guard message.isSent(by: myUserUuid),
              let messageId = message.messageId else { return [] }
        return receipts
            .filter { isRecipient($0, message: message, myUserUuid: myUserUuid) }
            .map { receipt in
                let status: MessageDeliveryStatus
                if let read = receipt.lastReadMessageId, read >= messageId {
                    status = .read
                } else if let delivered = receipt.lastDeliveredMessageId, delivered >= messageId {
                    status = .delivered
                } else {
                    status = .sent
                }
                return ParticipantDeliveryStatus(receipt: receipt, status: status)
            }
            .sorted { lhs, rhs in
                rank(lhs.status) < rank(rhs.status)
            }
    }

    private static func rank(_ status: MessageDeliveryStatus) -> Int {
        switch status {
        case .read: return 0
        case .delivered: return 1
        default: return 2
        }
    }

    private static func isRecipient(
        _ receipt: ChatReceipt,
        message: ChatMessage,
        myUserUuid: String?
    ) -> Bool {
        if receipt.userUuid == myUserUuid { return false }
        guard let joined = parseMillis(receipt.joinedAt),
              let created = parseMillis(message.createdAt) else {
            return true
        }
        return joined <= created
    }

    /// Сервер присылает LocalDateTime без зоны; трактуем как UTC.
    private static func parseMillis(_ iso: String?) -> Int64? {
        guard let iso, !iso.isEmpty else { return nil }
        let clipped = iso.count >= 19 ? String(iso.prefix(19)) : iso
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return parser.date(from: clipped).map { Int64($0.timeIntervalSince1970 * 1000) }
    }
}
