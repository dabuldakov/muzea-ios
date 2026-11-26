import SwiftUI

/// Действия над видео: как на Android, доступна либо своя кнопка удаления,
/// либо жалоба на чужой ролик.
enum VideoAction: String, CaseIterable, Identifiable {
    case delete
    case report

    var id: String { rawValue }

    var title: String {
        switch self {
        case .delete: return L10n.delete
        case .report: return L10n.report
        }
    }

    var systemImage: String {
        switch self {
        case .delete: return "trash"
        case .report: return "exclamationmark.bubble"
        }
    }

    var isDestructive: Bool { self == .delete }

    static func actions(canDelete: Bool) -> [VideoAction] {
        canDelete ? [.delete] : [.report]
    }
}

struct VideoActionsSheet: View {
    let canDelete: Bool
    let onAction: (VideoAction) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text(L10n.videoActions)
                .font(.headline)

            HStack(spacing: 24) {
                ForEach(VideoAction.actions(canDelete: canDelete)) { action in
                    Button {
                        dismiss()
                        onAction(action)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: action.systemImage)
                                .font(.title2)
                            Text(action.title)
                                .font(.caption)
                        }
                        .foregroundColor(action.isDestructive ? .red : .primary)
                        .frame(width: 104, height: 86)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(action.title)
                }
            }
        }
        .padding(24)
        .presentationDetents([.height(190)])
        .presentationDragIndicator(.visible)
    }
}
