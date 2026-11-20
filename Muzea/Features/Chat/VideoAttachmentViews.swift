import AVKit
import Photos
import SwiftUI
import UIKit

// MARK: - Full screen player

/// Полноэкранный плеер с явной кнопкой «назад»: нативный VideoPlayer в
/// fullScreenCover не всегда показывает кнопку закрытия.
struct FullScreenVideoPlayer: View {
    let player: AVPlayer

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: player)
                .ignoresSafeArea()

            Button {
                player.pause()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .padding(.leading, 12)
            .padding(.top, 8)
            .accessibilityLabel(L10n.close)
        }
        .onDisappear { player.pause() }
        .statusBarHidden(false)
    }
}

// MARK: - Video note

struct VideoNoteAttachmentView: View {
    let attachment: ChatAttachment

    @EnvironmentObject private var container: AppContainer
    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var showPlayer = false
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.25))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.largeTitle)
                    .foregroundColor(.white.opacity(0.7))
            }
            Image(systemName: isLoading ? "hourglass" : "play.fill")
                .font(.title3)
                .foregroundColor(.white)
                .padding(10)
                .background(Color.black.opacity(0.45))
                .clipShape(Circle())
        }
        .frame(width: 180, height: 180)
        .clipShape(Circle())
        .contentShape(Circle())
        .task(id: attachment.id) { await loadPreview() }
        .onTapGesture { Task { await play() } }
        .fullScreenCover(isPresented: $showPlayer) {
            if let player {
                FullScreenVideoPlayer(player: player)
            }
        }
    }

    private func loadPreview() async {
        guard let uuid = attachment.attachmentUuid else { return }
        let key = "preview-\(uuid)"
        if let cached = AttachmentImageCache.shared.cached(key: key) {
            image = cached
            return
        }
        guard let data = try? await container.attachmentRepository.preview(attachmentUuid: uuid),
              let loaded = UIImage(data: data) else { return }
        AttachmentImageCache.shared.store(loaded, key: key)
        image = loaded
    }

    private func play() async {
        guard let uuid = attachment.attachmentUuid else { return }
        if let player {
            showPlayer = true
            player.play()
            return
        }
        isLoading = true
        defer { isLoading = false }
        guard let url = await AttachmentFileCache.shared.localURL(
            attachmentUuid: uuid,
            fileName: attachment.fileName ?? "video-note.mp4",
            repository: container.attachmentRepository
        ) else { return }
        let player = AVPlayer(url: url)
        self.player = player
        showPlayer = true
        player.play()
    }
}

// MARK: - Video
struct VideoAttachmentView: View {
    let attachment: ChatAttachment
    let isMine: Bool

    @EnvironmentObject private var container: AppContainer
    @State private var player: AVPlayer?
    @State private var isLoading = false
    @State private var showPlayer = false
    @State private var shareFile: ShareFileItem?
    @State private var saveError: String?

    var body: some View {
        Button {
            Task { await open() }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.25))
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                }
                .frame(width: 52, height: 42)

                VStack(alignment: .leading, spacing: 1) {
                    Text(attachment.fileName ?? L10n.videoFallback)
                        .font(.footnote).bold()
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(isMine ? .white.opacity(0.8) : .secondary)
                }
                Spacer(minLength: 0)
                if isLoading { ProgressView() }
            }
            .padding(8)
            .frame(maxWidth: Theme.Size.mediaMaxWidth, alignment: .leading)
            .background(isMine ? Color.accentColor.opacity(0.85) : Color(.secondarySystemBackground))
            .foregroundColor(isMine ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.media))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .contextMenu {
            Button {
                Task { await saveToPhotos() }
            } label: {
                Label(L10n.saveToPhotos, systemImage: "square.and.arrow.down")
            }
            Button {
                Task { await share() }
            } label: {
                Label(L10n.share, systemImage: "square.and.arrow.up")
            }
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
        .fullScreenCover(isPresented: $showPlayer) {
            if let player {
                FullScreenVideoPlayer(player: player)
            }
        }
    }

    private var subtitle: String {
        if let duration = attachment.duration {
            return DurationFormatter.mmss(duration)
        }
        if let size = attachment.fileSize {
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        return L10n.videoFallback
    }

    private func open() async {
        guard player == nil else {
            showPlayer = true
            return
        }
        guard let url = await downloadURL() else { return }
        let player = AVPlayer(url: url)
        self.player = player
        showPlayer = true
        player.play()
    }

    private func downloadURL() async -> URL? {
        guard let uuid = attachment.attachmentUuid else { return nil }
        isLoading = true
        defer { isLoading = false }
        return await AttachmentFileCache.shared.localURL(
            attachmentUuid: uuid,
            fileName: attachment.fileName ?? "video.mp4",
            repository: container.attachmentRepository
        )
    }

    private func share() async {
        guard let url = await downloadURL() else { return }
        shareFile = ShareFileItem(url: url)
    }

    private func saveToPhotos() async {
        guard let url = await downloadURL() else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
        } catch {
            saveError = error.localizedDescription
        }
    }
}
