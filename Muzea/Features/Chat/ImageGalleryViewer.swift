import Photos
import SwiftUI
import UIKit

/// Полноэкранная галерея фото: свайпы, автор/дата, ответ/пересылка, share и
/// сохранение в Photos. Действия, которым нужен новый лист, выполняются
/// снаружи после закрытия галереи.
struct ImageGalleryViewer: View {
    let attachments: [ChatAttachment]
    let senderName: String?
    let createdAt: String?
    let onReply: () -> Void
    let onForward: () -> Void

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var images: [String: UIImage] = [:]
    @State private var shareFile: ShareFileItem?
    @State private var saveError: String?

    init(
        attachments: [ChatAttachment],
        startIndex: Int,
        senderName: String?,
        createdAt: String?,
        onReply: @escaping () -> Void,
        onForward: @escaping () -> Void
    ) {
        self.attachments = attachments
        self.senderName = senderName
        self.createdAt = createdAt
        self.onReply = onReply
        self.onForward = onForward
        _index = State(initialValue: min(max(startIndex, 0), max(attachments.count - 1, 0)))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(attachments.indices, id: \.self) { position in
                    Group {
                        if let image = images[attachments[position].id] {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        } else {
                            ProgressView().tint(.white)
                        }
                    }
                    .tag(position)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel(L10n.close)
                    VStack(alignment: .leading, spacing: 2) {
                        if let senderName, !senderName.isEmpty {
                            Text(senderName)
                                .font(.subheadline).bold()
                                .foregroundColor(.white)
                        }
                        if let createdAt, !createdAt.isEmpty {
                            Text(DateTimeFormat.full(createdAt))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    Spacer()
                    if attachments.count > 1 {
                        Text("\(index + 1)/\(attachments.count)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding()

                Spacer()

                HStack(spacing: 28) {
                    Button {
                        onReply()
                    } label: {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel(L10n.reply)

                    Button {
                        onForward()
                    } label: {
                        Image(systemName: "arrowshape.turn.up.right")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel(L10n.forward)

                    Button {
                        shareCurrent()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel(L10n.share)

                    Button {
                        saveCurrent()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel(L10n.saveToPhotos)
                }
                .padding(.bottom, 30)
            }
        }
        .task(id: index) {
            await load(index)
        }
        .sheet(item: $shareFile) { item in
            ActivityView(items: [item.url])
        }
        .alert(L10n.saveFailed, isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button(L10n.done, role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var currentImage: UIImage? {
        images[attachments[index].id]
    }

    private func load(_ position: Int) async {
        guard attachments.indices.contains(position),
              let uuid = attachments[position].attachmentUuid else { return }
        let key = "full-\(uuid)"
        if let cached = AttachmentImageCache.shared.cached(key: key) {
            images[attachments[position].id] = cached
            return
        }
        guard let data = try? await container.attachmentRepository.download(
            attachmentUuid: uuid
        ), let image = UIImage(data: data) else { return }
        AttachmentImageCache.shared.store(image, key: key)
        images[attachments[position].id] = image
    }

    private func shareCurrent() {
        guard let image = currentImage,
              let data = image.jpegData(compressionQuality: 0.95),
              let url = AttachmentFiles.write(data: data, fileName: "photo.jpg") else { return }
        shareFile = ShareFileItem(url: url)
    }

    private func saveCurrent() {
        guard let image = currentImage else { return }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if let error {
                    saveError = error.localizedDescription
                } else if success {
                    Haptics.success()
                }
            }
        }
    }
}
