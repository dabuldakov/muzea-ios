import SwiftUI
import UIKit

/// Вложения в пузыре: сетка фото, видео, аудио и документы. Каждый тип — свой
/// компонент, чтобы плееры и загрузки не смешивались в одном god-view.
struct MessageAttachmentsView: View {
    let attachments: [ChatAttachment]
    let isMine: Bool
    let messageType: String?
    /// Индекс нажатого превью в списке изображений. nil — галерея недоступна.
    let onOpenImage: ((Int) -> Void)?

    private var images: [ChatAttachment] {
        AttachmentPolicy.images(in: attachments)
    }

    private var others: [ChatAttachment] {
        attachments.filter { AttachmentPolicy.kind(of: $0) != .image }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !images.isEmpty {
                LazyVGrid(
                    columns: images.count == 1
                        ? [GridItem(.flexible())]
                        : [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 4
                ) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { index, attachment in
                        AttachmentImageCell(
                            attachment: attachment,
                            large: images.count == 1,
                            onOpen: { onOpenImage?(index) }
                        )
                    }
                }
                .frame(maxWidth: Theme.Size.mediaMaxWidth)
            }

            ForEach(others) { attachment in
                if messageType == "VIDEO_NOTE", AttachmentPolicy.kind(of: attachment) == .video {
                    VideoNoteAttachmentView(attachment: attachment)
                } else {
                    switch AttachmentPolicy.kind(of: attachment) {
                    case .video:
                        VideoAttachmentView(attachment: attachment, isMine: isMine)
                    case .audio:
                        AudioAttachmentView(attachment: attachment, isMine: isMine)
                    case .gif:
                        GifAttachmentView(attachment: attachment)
                    default:
                        FileAttachmentView(attachment: attachment, isMine: isMine)
                    }
                }
            }
        }
    }
}

// MARK: - Images

private struct AttachmentImageCell: View {
    let attachment: ChatAttachment
    let large: Bool
    let onOpen: () -> Void

    @EnvironmentObject private var container: AppContainer
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .onTapGesture(perform: onOpen)
            } else {
                Color(.tertiarySystemBackground)
                ProgressView()
            }
        }
        .frame(height: large ? 180 : 118)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.media))
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
