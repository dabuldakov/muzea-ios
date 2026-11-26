import AVFoundation
import SwiftUI
import UIKit

/// Слой AVPlayer без нативных контролов: нужен и детальному экрану, и
/// mini-плееру. Через него же создаётся `AVPictureInPictureController`, чтобы
/// PiP работал из любого места, где сейчас виден плеер.
struct VideoPlayerSurface: UIViewRepresentable {
    let player: AVPlayer
    var gravity: AVLayerVideoGravity = .resizeAspect
    let playback: VideoPlaybackManager

    func makeUIView(context: Context) -> VideoPlayerLayerView {
        let view = VideoPlayerLayerView()
        view.configure(player: player, gravity: gravity, playback: playback)
        return view
    }

    func updateUIView(_ uiView: VideoPlayerLayerView, context: Context) {
        uiView.configure(player: player, gravity: gravity, playback: playback)
    }

    static func dismantleUIView(_ uiView: VideoPlayerLayerView, coordinator: ()) {
        uiView.detach()
    }
}

final class VideoPlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer {
        // layerClass гарантирует этот тип.
        layer as! AVPlayerLayer
    }

    private weak var playback: VideoPlaybackManager?
    private var pipController: AVPictureInPictureController?

    func configure(
        player: AVPlayer,
        gravity: AVLayerVideoGravity,
        playback: VideoPlaybackManager
    ) {
        playerLayer.player = player
        playerLayer.videoGravity = gravity
        self.playback = playback

        guard pipController == nil,
              AVPictureInPictureController.isPictureInPictureSupported(),
              let controller = AVPictureInPictureController(playerLayer: playerLayer)
        else { return }
        pipController = controller
        playback.attach(controller)
    }

    func detach() {
        playerLayer.player = nil
        if let pipController {
            playback?.detach(pipController)
        }
        pipController = nil
        playback = nil
    }
}
