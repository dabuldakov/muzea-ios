import AVKit
import Photos
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
                    .accessibilityLabel("Закрыть")
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
                    .accessibilityLabel("Ответить")

                    Button {
                        onForward()
                    } label: {
                        Image(systemName: "arrowshape.turn.up.right")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel("Переслать")

                    Button {
                        shareCurrent()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel("Поделиться")

                    Button {
                        saveCurrent()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel("Сохранить в Фото")
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
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
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
                Label("Сохранить в Photos", systemImage: "square.and.arrow.down")
            }
            Button {
                Task { await share() }
            } label: {
                Label("Поделиться", systemImage: "square.and.arrow.up")
            }
        }
        .sheet(item: $shareFile) { item in
            ActivityView(items: [item.url])
        }
        .alert("Не удалось сохранить", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
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

// MARK: - Audio

private struct AudioAttachmentView: View {
    let attachment: ChatAttachment
    let isMine: Bool

    @EnvironmentObject private var container: AppContainer
    @ObservedObject private var audio = AudioPlaybackCenter.shared
    @State private var levels: [Double] = []

    private var isCurrent: Bool { audio.playingId == attachment.id }
    private var isPlaying: Bool { audio.isPlaying(attachment.id) }

    private var displayedLevels: [Double] {
        levels.isEmpty
            ? Array(repeating: Waveform.minimumLevel, count: Waveform.defaultBarCount)
            : levels
    }

    private var totalSeconds: Int {
        if let duration = attachment.duration, duration > 0 { return duration }
        if isCurrent, audio.duration > 0 { return Int(audio.duration.rounded()) }
        return 0
    }

    private var timeLabel: String {
        let total = DurationFormatter.mmss(totalSeconds)
        guard isCurrent, audio.duration > 0 else { return total }
        let elapsed = DurationFormatter.mmss(Int((audio.duration * audio.progress).rounded()))
        return "\(elapsed) / \(total)"
    }

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
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    WaveformBars(
                        levels: displayedLevels,
                        progress: isCurrent ? audio.progress : 0,
                        activeColor: isMine ? .white : .accentColor,
                        idleColor: isMine ? .white.opacity(0.4) : Color.secondary.opacity(0.3)
                    )
                    .frame(height: 24)

                    HStack(spacing: 6) {
                        Text(attachment.fileName ?? "Голосовое сообщение")
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(timeLabel)
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .foregroundColor(isMine ? .white.opacity(0.85) : .secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: Theme.Size.mediaMaxWidth, alignment: .leading)
            .background(isMine ? Color.accentColor.opacity(0.85) : Color(.secondarySystemBackground))
            .foregroundColor(isMine ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.media))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Пауза" : "Воспроизвести голосовое сообщение")
        .accessibilityValue(timeLabel)
        .task(id: attachment.id) {
            guard levels.isEmpty else { return }
            levels = await WaveformProvider.shared.waveform(
                for: attachment,
                repository: container.attachmentRepository
            ) ?? []
        }
    }
}

// MARK: - Waveform

/// Столбцы волны: проигранная часть подсвечивается, остальная — приглушена.
struct WaveformBars: View {
    let levels: [Double]
    let progress: Double
    let activeColor: Color
    let idleColor: Color

    private var played: Int {
        Waveform.playedCount(total: levels.count, progress: progress)
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 2) {
                ForEach(levels.indices, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(index < played ? activeColor : idleColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: barHeight(index, in: geometry.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .accessibilityHidden(true)
    }

    private func barHeight(_ index: Int, in height: CGFloat) -> CGFloat {
        let level = levels.indices.contains(index) ? levels[index] : Waveform.minimumLevel
        return max(3, height * CGFloat(min(1, max(0, level))))
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
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.media))
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
                Label("Поделиться", systemImage: "square.and.arrow.up")
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
        return "Файл"
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
