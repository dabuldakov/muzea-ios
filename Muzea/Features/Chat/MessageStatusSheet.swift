import SwiftUI

/// «Детали» сообщения: кто поставил реакции и когда, а для своих сообщений в
/// группе — кто доставил и прочитал. Точные отметки времени приходят из
/// `/status/{messageUuid}`, а не из watermark квитанций.
struct MessageStatusSheet: View {
    let message: ChatMessage
    let receipts: [ChatReceipt]
    let statuses: [MessageStatus]
    let myUserUuid: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !reactionRows.isEmpty {
                    Section(L10n.reactionsSection) {
                        ForEach(reactionRows) { row in
                            HStack(spacing: 12) {
                                Text(row.emoji).font(.title3)
                                AvatarView(url: ImageURL.chat(row.avatarUrl), size: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.name)
                                    Text(row.time.isEmpty ? L10n.reacted : row.time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                if !deliveryRows.isEmpty {
                    Section(L10n.deliveryStatus) {
                        ForEach(deliveryRows) { row in
                            HStack(spacing: 12) {
                                AvatarView(url: ImageURL.chat(row.avatarUrl), size: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.name)
                                    Text(row.timeText)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: row.icon)
                                    .foregroundColor(row.status == .read ? .accentColor : .secondary)
                            }
                        }
                    }
                }

                if reactionRows.isEmpty && deliveryRows.isEmpty {
                    Text(L10n.noData)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(L10n.messageDetails)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var reactionRows: [ReactionRow] {
        var seen = Set<String>()
        var rows: [ReactionRow] = []
        for reaction in message.reactions ?? [] {
            for user in reaction.users ?? [] {
                guard let userUuid = user.userUuid, seen.insert(userUuid).inserted else { continue }
                let receipt = receipts.first { $0.userUuid == userUuid }
                rows.append(ReactionRow(
                    id: userUuid,
                    emoji: reaction.emoji,
                    name: name(for: userUuid, receipt: receipt),
                    avatarUrl: receipt?.avatarUrl,
                    time: DateTimeFormat.time(user.at)
                ))
            }
        }
        return rows
    }

    private var deliveryRows: [DeliveryRow] {
        MessageStatusCalculator.participantStatuses(
            message: message,
            receipts: receipts,
            myUserUuid: myUserUuid
        )
        .map { row in
            let exact = statuses.first { $0.userUuid == row.receipt.userUuid }
            let fallback = row.status == .read
                ? row.receipt.lastReadAt
                : row.receipt.lastDeliveredAt
            let time = DateTimeFormat.time(
                row.status == .read ? (exact?.readAt ?? fallback) : (exact?.deliveredAt ?? fallback)
            )
            return DeliveryRow(
                id: row.receipt.userUuid ?? "\(row.receipt.username ?? "unknown")",
                name: row.receipt.displayName,
                avatarUrl: row.receipt.avatarUrl,
                status: row.status,
                time: time
            )
        }
    }

    private func name(for userUuid: String, receipt: ChatReceipt?) -> String {
        if userUuid == myUserUuid { return L10n.you }
        return receipt?.displayName ?? L10n.unknownUser
    }

    private struct ReactionRow: Identifiable {
        let id: String
        let emoji: String
        let name: String
        let avatarUrl: String?
        let time: String
    }

    private struct DeliveryRow: Identifiable {
        let id: String
        let name: String
        let avatarUrl: String?
        let status: MessageDeliveryStatus
        let time: String

        var icon: String {
            switch status {
            case .read: return "checkmark.circle.fill"
            case .delivered: return "checkmark.circle"
            default: return "checkmark"
            }
        }

        var timeText: String {
            let label: String
            switch status {
            case .read: label = L10n.statusRead
            case .delivered: label = L10n.statusDelivered
            default: label = L10n.statusSent
            }
            return time.isEmpty ? label : "\(label) · \(time)"
        }
    }
}
