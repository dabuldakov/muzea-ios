import SwiftUI

/// Панель закреплённого сообщения над лентой. Показывает последнее закрепление,
/// позволяет перейти к нему и открепить.
struct PinnedMessagesBar: View {
    let pinned: [MessageResponse]
    let onOpen: (MessageResponse) -> Void
    let onUnpin: () -> Void

    var body: some View {
        if let first = pinned.first {
            HStack(spacing: 10) {
                Image(systemName: "pin.fill")
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(pinned.count > 1 ? "Закреплённые: \(pinned.count)" : "Закреплённое сообщение")
                        .font(.caption2).bold()
                    Text(MessagePreviewText.preview(first))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(action: onUnpin) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .contentShape(Rectangle())
            .onTapGesture { onOpen(first) }
        }
    }
}
