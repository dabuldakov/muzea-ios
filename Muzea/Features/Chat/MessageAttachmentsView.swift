import AVKit
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

/// Вложения в пузыре: сетка фото, видео, аудио и документы. Каждый тип — свой
/// компонент, чтобы плееры и загрузки не смешивались в одном god-view.
struct MessageAttachmentsView: View {
    let attachments: [ChatAttachment]
    let isMine: Bool
    let messageType: String?

    private var images: [ChatAttachment] {
        attachments.filter { kind($0) == .image }
    }

    private var others: [ChatAttachment] {
        attachments.filter { kind($0) != .image }
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
                    ForEach(images) { attachment in
                        AttachmentImageCell(attachment: attachment, large: images.count == 1)
                    }
                }
                .frame(maxWidth: 250)
            }

            ForEach(others) { attachment in
                if messageType == "VIDEO_NOTE", kind(attachment) == .video {
                    VideoNoteAttachmentView(attachment: attachment)
                } else {
                    switch kind(attachment) {
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

    private func kind(_ attachment: ChatAttachment) -> AttachmentKind {
        AttachmentPolicy.kind(fromServerType: attachment.type)
            ?? AttachmentPolicy.rule(for: attachment.fileName ?? "")?.kind
            ?? .document
    }
}

// MARK: - Images

private struct AttachmentImageCell: View {
    let attachment: ChatAttachment
    let large: Bool

    @EnvironmentObject private var container: AppContainer
    @State private var image: UIImage?
    @State private var viewer: ImageViewerItem?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .onTapGesture { viewer = ImageViewerItem(image: image) }
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
        .sheet(item: $viewer) { item in
            ImageAttachmentViewer(image: item.image)
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

private struct ImageViewerItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ImageAttachmentViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var shareFile: ShareFileItem?

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
                HStack {
                    Spacer()
                    Button {
                        if let data = image.jpegData(compressionQuality: 0.95),
                           let url = AttachmentFiles.write(data: data, fileName: "photo.jpg") {
                            shareFile = ShareFileItem(url: url)
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .padding()
                }
            }
        }
        .sheet(item: $shareFile) { item in
            ActivityView(items: [item.url])
        }
    }
}

// MARK: - Video note

private struct VideoNoteAttachmentView: View {
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
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onDisappear { player.pause() }
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
private struct VideoAttachmentView: View {
    let attachment: ChatAttachment
    let isMine: Bool

    @EnvironmentObject private var container: AppContainer
    @State private var player: AVPlayer?
    @State private var isLoading = false
    @State private var showPlayer = false

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
                    Text(attachment.fileName ?? "Видео")
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
            .frame(maxWidth: 250, alignment: .leading)
            .background(isMine ? Color.accentColor.opacity(0.85) : Color(.secondarySystemBackground))
            .foregroundColor(isMine ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .fullScreenCover(isPresented: $showPlayer) {
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onDisappear { player.pause() }
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
        return "Видео"
    }

    private func open() async {
        guard player == nil, let uuid = attachment.attachmentUuid else {
            showPlayer = player != nil
            return
        }
        isLoading = true
        defer { isLoading = false }
        guard let url = await AttachmentFileCache.shared.localURL(
            attachmentUuid: uuid,
            fileName: attachment.fileName ?? "video.mp4",
            repository: container.attachmentRepository
        ) else { return }
        let player = AVPlayer(url: url)
        self.player = player
        showPlayer = true
        player.play()
    }
}

// MARK: - Audio

private struct AudioAttachmentView: View {
    let attachment: ChatAttachment
    let isMine: Bool

    @EnvironmentObject private var container: AppContainer
    @ObservedObject private var audio = AudioPlaybackCenter.shared

    var body: some View {
        Button {
            Task {
                await audio.toggle(
                    id: attachment.id,
                    attachment: attachment,
                    repository: container.attachmentRepository
                )
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: audio.isPlaying(attachment.id) ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(attachment.fileName ?? "Аудио")
                        .font(.footnote)
                        .lineLimit(1)
                    if audio.playingId == attachment.id {
                        ProgressView(value: audio.progress)
                            .tint(isMine ? .white : .accentColor)
                    } else {
                        Text(attachment.duration.map(DurationFormatter.mmss) ?? "Аудио")
                            .font(.caption2)
                            .foregroundColor(isMine ? .white.opacity(0.8) : .secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: 250, alignment: .leading)
            .background(isMine ? Color.accentColor.opacity(0.85) : Color(.secondarySystemBackground))
            .foregroundColor(isMine ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - GIF

private struct GifAttachmentView: View {
    let attachment: ChatAttachment

    private var videoURL: URL? {
        AttachmentURLResolver.absolute(attachment.mp4Url, base: Config.chatBaseURL)
    }

    private var previewURL: URL? {
        AttachmentURLResolver.absolute(
            attachment.thumbnailUrl ?? attachment.fileUrl,
            base: Config.chatBaseURL
        )
    }

    private var ratio: CGFloat {
        guard let width = attachment.width, let height = attachment.height, height > 0 else {
            return 1
        }
        return CGFloat(width) / CGFloat(height)
    }

    var body: some View {
        Group {
            if let videoURL {
                LoopingVideoView(url: videoURL)
            } else if let previewURL {
                AsyncImage(url: previewURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        Color(.tertiarySystemBackground)
                    }
                }
            } else {
                EmptyView()
            }
        }
        .frame(width: min(220, 220 * ratio), height: min(220, 220 / ratio))
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Беззвучный зацикленный MP4 вместо GIF/WebP: плавнее и легче.
struct LoopingVideoView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        let looper = AVPlayerLooper(player: player, templateItem: item)
        player.isMuted = true
        player.play()
        view.attach(player: player, looper: looper)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {}

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: ()) {
        uiView.stop()
    }
}

final class PlayerContainerView: UIView {
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private let playerLayer = AVPlayerLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(playerLayer)
        playerLayer.videoGravity = .resizeAspectFill
        backgroundColor = .secondarySystemBackground
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func attach(player: AVQueuePlayer, looper: AVPlayerLooper) {
        self.player = player
        self.looper = looper
        playerLayer.player = player
    }

    func stop() {
        player?.pause()
        playerLayer.player = nil
        looper = nil
        player = nil
    }
}

// MARK: - Files

private struct FileAttachmentView: View {
    let attachment: ChatAttachment
    let isMine: Bool

    @EnvironmentObject private var container: AppContainer
    @State private var isDownloading = false
    @State private var shareFile: ShareFileItem?

    var body: some View {
        Button {
            Task { await open() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc")
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
        .sheet(item: $shareFile) { item in
            ActivityView(items: [item.url])
        }
    }

    private var subtitle: String {
        if let size = attachment.fileSize {
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        return "Файл"
    }

    private func open() async {
        guard let uuid = attachment.attachmentUuid else { return }
        isDownloading = true
        defer { isDownloading = false }
        guard let url = await AttachmentFileCache.shared.localURL(
            attachmentUuid: uuid,
            fileName: attachment.fileName ?? "attachment",
            repository: container.attachmentRepository
        ) else { return }
        shareFile = ShareFileItem(url: url)
    }
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
