import AVFoundation
import Foundation

/// Один аудиоплеер на экран чата: переключение между сообщениями, пауза и
/// прогресс. Аналог `ChatAudioController` на Android.
final class AudioPlaybackCenter: NSObject, ObservableObject {
    static let shared = AudioPlaybackCenter()

    @Published private(set) var playingId: String?
    @Published private(set) var progress: Double = 0
    @Published private(set) var duration: Double = 0

    private var player: AVAudioPlayer?
    private var ticker: Task<Void, Never>?

    @MainActor
    func isPlaying(_ id: String) -> Bool {
        playingId == id && (player?.isPlaying ?? false)
    }

    @MainActor
    func toggle(
        id: String,
        attachment: AttachmentResponse,
        repository: AttachmentRepository
    ) async {
        if playingId == id, let player {
            if player.isPlaying {
                player.pause()
                ticker?.cancel()
            } else {
                player.play()
                startTicker()
            }
            objectWillChange.send()
            return
        }

        guard let uuid = attachment.attachmentUuid,
              let url = await AttachmentFileCache.shared.localURL(
                attachmentUuid: uuid,
                fileName: attachment.fileName ?? "audio.m4a",
                repository: repository
              ) else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            stopTicker()
            self.player?.stop()
            self.player = player
            playingId = id
            duration = player.duration
            progress = 0
            player.play()
            startTicker()
        } catch {
            reset()
        }
    }

    @MainActor
    func stop() {
        player?.stop()
        reset()
    }

    @MainActor
    private func startTicker() {
        ticker?.cancel()
        ticker = Task { @MainActor in
            while !Task.isCancelled, let player, player.isPlaying {
                progress = player.duration > 0 ? player.currentTime / player.duration : 0
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    @MainActor
    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    @MainActor
    private func reset() {
        stopTicker()
        player = nil
        playingId = nil
        progress = 0
        duration = 0
    }
}

extension AudioPlaybackCenter: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.reset()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.reset()
        }
    }
}
