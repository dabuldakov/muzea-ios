import SwiftUI

/// Компактное меню вложений, как на Android: три круглые иконки без подписей
/// в списке, но с подписями и accessibility на iOS.
struct AttachmentMenuSheet: View {
    let onPhoto: () -> Void
    let onVideo: () -> Void
    let onFile: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color(.separator))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            HStack(spacing: 24) {
                button(icon: "photo.on.rectangle", title: L10n.photo, action: onPhoto)
                button(icon: "video", title: L10n.video, action: onVideo)
                button(icon: "folder", title: L10n.file, action: onFile)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(170)])
        .presentationDragIndicator(.hidden)
    }

    private func button(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(.accentColor)
                    .frame(width: 64, height: 64)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(width: 84)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
