import SwiftUI

/// Плавающая карточка действий над сообщением — аналог Android
/// `MessageActionsPopup`. Появляется по тапу у самого пузыря: сверху реакции,
/// ниже иконки действий, снизу раскрываемый список «кто прочитал / реагировал».
struct MessageActionsPopupView: View {
    let message: ChatMessage
    let actions: [MessageAction]
    let showDetails: Bool
    let receipts: [ChatReceipt]
    let statuses: [MessageStatus]
    let myUserUuid: String?
    let recentReactions: [String]
    let anchor: CGPoint

    let onAction: (MessageAction) -> Void
    let onReaction: (String) -> Void
    let onLoadDetails: () -> Void
    let onDismiss: () -> Void

    @State private var reactionsExpanded = false
    @State private var detailsExpanded = false
    @State private var cardHeight: CGFloat = 0

    private let actionColumns = Array(
        repeating: GridItem(.flexible(), spacing: 6),
        count: 6
    )
    private let reactionColumns = Array(
        repeating: GridItem(.flexible(), spacing: 4),
        count: 7
    )

    var body: some View {
        GeometryReader { geo in
            let width = min(max(geo.size.width - 24, 260), 360)
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)

                card
                    .frame(width: width)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: PopupHeightPreferenceKey.self,
                                value: proxy.size.height
                            )
                        }
                    )
                    .offset(
                        x: xOffset(width: width, in: geo.size),
                        y: yOffset(in: geo.size)
                    )
                    .opacity(cardHeight > 0 ? 1 : 0)
            }
            .onPreferenceChange(PopupHeightPreferenceKey.self) { cardHeight = $0 }
        }
        .transition(.opacity)
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 0) {
            reactionsSection

            Divider().padding(.top, 6)

            LazyVGrid(columns: actionColumns, spacing: 6) {
                ForEach(actions, id: \.self) { action in
                    Button {
                        onAction(action)
                    } label: {
                        Image(systemName: action.systemImage)
                            .font(.system(size: 18))
                            .foregroundColor(action.isDestructive ? .red : .primary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(action.title)
                }
            }
            .padding(.top, 8)

            if showDetails {
                detailsSection
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 18, y: 6)
    }

    // MARK: - Reactions

    @ViewBuilder
    private var reactionsSection: some View {
        if reactionsExpanded {
            LazyVGrid(columns: reactionColumns, spacing: 4) {
                ForEach(orderedReactions, id: \.self) { emoji in
                    reactionButton(emoji, size: 36)
                }
            }
        } else {
            HStack(spacing: 4) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(stripReactions, id: \.self) { emoji in
                            reactionButton(emoji, size: 36)
                        }
                    }
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        reactionsExpanded = true
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.allReactions)
            }
            .frame(height: 40)
        }
    }

    private func reactionButton(_ emoji: String, size: CGFloat) -> some View {
        Button {
            onReaction(emoji)
        } label: {
            Text(emoji)
                .font(.system(size: size * 0.58))
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(emoji)
    }

    private var stripReactions: [String] {
        Array(recentReactions.prefix(ReactionCatalog.stripLimit))
    }

    /// Сначала последние использованные, затем остальные — как
    /// `ReactionOrder.ordered` на Android.
    private var orderedReactions: [String] {
        recentReactions + ReactionCatalog.all.filter { !recentReactions.contains($0) }
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(spacing: 0) {
            Divider().padding(.top, 8)

            Button {
                if !detailsExpanded {
                    onLoadDetails()
                }
                withAnimation(.easeInOut(duration: 0.18)) {
                    detailsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                    Text(L10n.messageDetails)
                    Spacer(minLength: 8)
                    Image(systemName: detailsExpanded ? "chevron.up" : "chevron.down")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.top, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if detailsExpanded {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(detailRows) { row in
                            detailRow(row)
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxHeight: min(220, CGFloat(detailRows.count) * 44))
            }
        }
    }

    private var detailRows: [MessagePopupRow] {
        MessagePopupRows.build(
            message: message,
            receipts: receipts,
            statuses: statuses,
            myUserUuid: myUserUuid,
            youLabel: L10n.you,
            unknownLabel: L10n.unknownUser,
            formatTime: { DateTimeFormat.time($0) }
        )
    }

    private func detailRow(_ row: MessagePopupRow) -> some View {
        HStack(spacing: 8) {
            AvatarView(url: ImageURL.chat(row.avatarUrl), size: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(row.name)
                    .font(.subheadline)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(subtitle(for: row))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    if let status = row.status {
                        Image(systemName: statusIcon(status))
                            .font(.caption2)
                            .foregroundColor(status == .read ? .accentColor : .secondary)
                    }
                }
            }

            Spacer(minLength: 4)

            emojiChips(row.emojis)
        }
    }

    private func subtitle(for row: MessagePopupRow) -> String {
        guard let status = row.status else {
            return row.time.isEmpty ? L10n.reacted : row.time
        }
        let label: String
        switch status {
        case .read: label = L10n.statusRead
        case .delivered: label = L10n.statusDelivered
        default: label = L10n.statusSent
        }
        return row.time.isEmpty ? label : "\(label) · \(row.time)"
    }

    private func statusIcon(_ status: MessageDeliveryStatus) -> String {
        switch status {
        case .read: return "checkmark.circle.fill"
        case .delivered: return "checkmark.circle"
        default: return "checkmark"
        }
    }

    @ViewBuilder
    private func emojiChips(_ emojis: [String]) -> some View {
        let visible = MessagePopupRows.visibleEmojis(emojis)
        if !visible.shown.isEmpty {
            HStack(spacing: 2) {
                ForEach(Array(visible.shown.enumerated()), id: \.offset) { _, emoji in
                    Text(emoji).font(.system(size: 15))
                }
                if visible.hidden > 0 {
                    Text("+\(visible.hidden)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Position

    private func xOffset(width: CGFloat, in size: CGSize) -> CGFloat {
        let margin: CGFloat = 12
        let maxX = max(margin, size.width - width - margin)
        return min(max(anchor.x - width / 2, margin), maxX)
    }

    private func yOffset(in size: CGSize) -> CGFloat {
        let margin: CGFloat = 8
        let preferBelow = anchor.y < size.height / 2
        let proposed = preferBelow
            ? anchor.y + margin
            : anchor.y - cardHeight - margin
        let maxY = max(margin, size.height - cardHeight - margin)
        return min(max(proposed, margin), maxY)
    }
}

private struct PopupHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
