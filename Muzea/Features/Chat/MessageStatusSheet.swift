import SwiftUI

/// Кто прочитал или получил конкретное сообщение. Водяные знаки пересчитываются
/// чистым `MessageStatusCalculator`, поэтому шторка не знает о сети.
struct MessageStatusSheet: View {
    let message: MessageResponse
    let receipts: [ChatReceiptResponse]
    let myUserUuid: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if rows.isEmpty {
                    Text("Пока нет получателей")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(rows, id: \.receipt.userUuid) { row in
                        HStack(spacing: 12) {
                            AvatarView(url: ImageURL.chat(row.receipt.avatarUrl), size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.receipt.displayName).font(.body)
                                Text(statusText(row))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: icon(row.status))
                                .foregroundColor(row.status == .read ? .accentColor : .secondary)
                        }
                    }
                }
            }
            .navigationTitle("Статус сообщения")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var rows: [ParticipantDeliveryStatus] {
        MessageStatusCalculator.participantStatuses(
            message: message,
            receipts: receipts,
            myUserUuid: myUserUuid
        )
    }

    private func statusText(_ row: ParticipantDeliveryStatus) -> String {
        let time: String?
        switch row.status {
        case .read:
            time = DateTimeFormat.time(row.receipt.lastReadAt)
        case .delivered:
            time = DateTimeFormat.time(row.receipt.lastDeliveredAt)
        default:
            time = DateTimeFormat.time(row.receipt.lastDeliveredAt)
        }
        let label: String
        switch row.status {
        case .read: label = "Прочитано"
        case .delivered: label = "Доставлено"
        default: label = "Отправлено"
        }
        return time.isEmpty ? label : "\(label) · \(time)"
    }

    private func icon(_ status: MessageDeliveryStatus) -> String {
        switch status {
        case .read: return "checkmark.circle.fill"
        case .delivered: return "checkmark.circle"
        default: return "checkmark"
        }
    }
}
