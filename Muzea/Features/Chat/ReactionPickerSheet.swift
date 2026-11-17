import SwiftUI

/// Выбор реакции: последние использованные и полный набор, как на Android.
struct ReactionPickerSheet: View {
    let recent: [String]
    let all: [String]
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !recent.isEmpty {
                        Text(L10n.recentReactions)
                            .font(.caption).foregroundColor(.secondary)
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(Array(recent.prefix(ReactionCatalog.stripLimit)), id: \.self) { emoji in
                                emojiButton(emoji, size: 40)
                            }
                        }
                    }

                    Text(L10n.allReactions)
                        .font(.caption).foregroundColor(.secondary)
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(all, id: \.self) { emoji in
                            emojiButton(emoji, size: 40)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle(L10n.reaction)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func emojiButton(_ emoji: String, size: CGFloat) -> some View {
        Button {
            onPick(emoji)
            dismiss()
        } label: {
            Text(emoji)
                .font(.system(size: size * 0.6))
                .frame(width: size, height: size)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
