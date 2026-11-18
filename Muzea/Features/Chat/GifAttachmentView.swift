import AVFoundation
import SwiftUI
import UIKit

// MARK: - GIF

struct GifAttachmentView: View {
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
        super.init(coder: coder)
        layer.addSublayer(playerLayer)
        playerLayer.videoGravity = .resizeAspectFill
        backgroundColor = .secondarySystemBackground
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
