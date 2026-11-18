import SwiftUI
import UIKit

// MARK: - Files

struct FileAttachmentView: View {
    let attachment: ChatAttachment
    let isMine: Bool

    @EnvironmentObject private var container: AppContainer
    @State private var isDownloading = false
    @State private var previewItem: FilePreviewItem?
    @State private var shareFile: ShareFileItem?

    var body: some View {
        Button {
            Task { await open(share: false) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc")
                    .font(.title3)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text(attachment.fileName ?? L10n.attachmentFallback)
                        .font(.footnote).bold()
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(isMine ? .white.opacity(0.8) : .secondary)
                }

                Spacer(minLength: 0)

                if isDownloading {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .frame(maxWidth: Theme.Size.mediaMaxWidth, alignment: .leading)
            .background(isMine ? Color.accentColor.opacity(0.85) : Color(.secondarySystemBackground))
            .foregroundColor(isMine ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.media))
        }
        .buttonStyle(.plain)
        .disabled(isDownloading)
        .contextMenu {
            Button {
                Task { await open(share: true) }
            } label: {
                Label(L10n.share, systemImage: "square.and.arrow.up")
            }
        }
        .sheet(item: $previewItem) { item in
            QuickLookView(url: item.url)
        }
        .sheet(item: $shareFile) { item in
            ActivityView(items: [item.url])
        }
    }

    private var subtitle: String {
        if let size = attachment.fileSize {
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        return L10n.fileFallback
    }

    private func open(share: Bool) async {
        guard let uuid = attachment.attachmentUuid else { return }
        isDownloading = true
        defer { isDownloading = false }
        guard let url = await AttachmentFileCache.shared.localURL(
            attachmentUuid: uuid,
            fileName: attachment.fileName ?? "attachment",
            repository: container.attachmentRepository
        ) else { return }
        if share {
            shareFile = ShareFileItem(url: url)
        } else {
            previewItem = FilePreviewItem(url: url)
        }
    }
}

private struct FilePreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareFileItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// Системный share sheet.
