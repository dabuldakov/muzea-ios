import SwiftUI
import UIKit

/// Кэш картинок вложений: пузыри не должны скачивать одно и то же при каждой
/// перерисовке. Ключ включает uuid и вариант (preview/full).
final class AttachmentImageCache {
    static let shared = AttachmentImageCache()
    private let cache = NSCache<NSString, UIImage>()

    func cached(key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func store(_ image: UIImage, key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

/// Вложения в пузыре: сетка фото, карточки видео/аудио/документов.
struct MessageAttachmentsView: View {
    let attachments: [AttachmentResponse]
    let isMine: Bool

    @EnvironmentObject private var container: AppContainer
    @State private var viewer: ImageViewerItem?
    @State private var shareFile: ShareFileItem?

    private var images: [AttachmentResponse] { attachments.filter { kind($0) == .image } }
    private var others: [AttachmentResponse] { attachments.filter { kind($0) != .image } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !images.isEmpty {
                LazyVGrid(
                    columns: images.count == 1
                        ? [GridItem(.flexible())]
                        : [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 4
                ) {
                    ForEach(images) { attachment in
                        AttachmentImageCell(
                            attachment: attachment,
                            large: images.count == 1,
                            onOpen: { image in viewer = ImageViewerItem(image: image) }
                        )
                    }
                }
                .frame(maxWidth: 250)
            }

            ForEach(others) { attachment in
                AttachmentCard(
                    attachment: attachment,
                    isMine: isMine,
                    onShare: { url in shareFile = ShareFileItem(url: url) }
                )
            }
        }
        .sheet(item: $viewer) { item in
            ImageAttachmentViewer(image: item.image)
        }
        .sheet(item: $shareFile) { item in
            ActivityView(items: [item.url])
        }
    }

    private func kind(_ attachment: AttachmentResponse) -> AttachmentKind {
        AttachmentPolicy.kind(fromServerType: attachment.type)
            ?? AttachmentPolicy.rule(for: attachment.fileName ?? "")?.kind
            ?? .document
    }
}

private struct AttachmentImageCell: View {
    let attachment: AttachmentResponse
    let large: Bool
    let onOpen: (UIImage) -> Void

    @EnvironmentObject private var container: AppContainer
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .onTapGesture { onOpen(image) }
            } else {
                Color(.tertiarySystemBackground)
                ProgressView()
            }
        }
        .frame(height: large ? 180 : 118)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: attachment.id) {
            image = await loadImage()
        }
    }

    private func loadImage() async -> UIImage? {
        guard let uuid = attachment.attachmentUuid else { return nil }
        let key = "preview-\(uuid)"
        if let cached = AttachmentImageCache.shared.cached(key: key) { return cached }
        guard let data = try? await container.attachmentRepository.preview(attachmentUuid: uuid),
              let image = UIImage(data: data) else { return nil }
        AttachmentImageCache.shared.store(image, key: key)
        return image
    }
}

private struct AttachmentCard: View {
    let attachment: AttachmentResponse
    let isMine: Bool
    let onShare: (URL) -> Void

    @EnvironmentObject private var container: AppContainer
    @State private var isDownloading = false

    var body: some View {
        Button {
            Task { await open() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text(attachment.fileName ?? "Вложение")
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
            .frame(maxWidth: 250, alignment: .leading)
            .background(isMine ? Color.accentColor.opacity(0.85) : Color(.secondarySystemBackground))
            .foregroundColor(isMine ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isDownloading)
    }

    private var kind: AttachmentKind {
        AttachmentPolicy.kind(fromServerType: attachment.type)
            ?? AttachmentPolicy.rule(for: attachment.fileName ?? "")?.kind
            ?? .document
    }

    private var icon: String {
        switch kind {
        case .video: return "play.rectangle"
        case .audio: return "waveform"
        case .image: return "photo"
        default: return "doc"
        }
    }

    private var subtitle: String {
        if let size = attachment.fileSize {
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        return kind.rawValue.capitalized
    }

    private func open() async {
        guard let uuid = attachment.attachmentUuid else { return }
        isDownloading = true
        defer { isDownloading = false }
        guard let data = try? await container.attachmentRepository.download(attachmentUuid: uuid),
              let url = AttachmentFiles.write(
                data: data,
                fileName: attachment.fileName ?? "attachment"
              ) else { return }
        onShare(url)
    }
}

struct ImageAttachmentViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

private struct ImageViewerItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ShareFileItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// Системный share sheet.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
