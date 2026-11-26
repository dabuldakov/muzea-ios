import AVFoundation
import AVKit
import Combine
import Foundation
import UIKit

/// Общий плеер приложения: один `AVPlayer` на процесс.
///
/// Благодаря этому видео продолжает играть при возврате из детали, а на
/// вкладках показывается mini-плеер. Закрывает плеер только явная кнопка
/// «закрыть», удаление ролика или выход из аккаунта.
@MainActor
final class VideoPlaybackManager: NSObject, ObservableObject {
    @Published private(set) var activeVideo: Video?
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var detailVisible = false
    @Published private(set) var isPictureInPictureActive = false
    @Published var error: String?

    let player = AVPlayer()

    private let tokenProvider: () -> String?
    private let networkMonitor: NetworkMonitor
    private let cache: VideoDiskCache

    private var currentRemoteURL: URL?
    private var timeControlObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var failedObserver: NSObjectProtocol?
    private var retryTask: Task<Void, Never>?
    private weak var pipController: AVPictureInPictureController?

    private static let seekStep: Double = 10
    private static let retryAttempts = 30
    private static let retryDelay: UInt64 = 2_000_000_000

    init(
        tokenProvider: @escaping () -> String?,
        networkMonitor: NetworkMonitor,
        cache: VideoDiskCache = .shared
    ) {
        self.tokenProvider = tokenProvider
        self.networkMonitor = networkMonitor
        self.cache = cache
        super.init()
        URLCache.shared = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 300 * 1024 * 1024,
            diskPath: "video_http_cache"
        )
        player.automaticallyWaitsToMinimizeStalling = true
        observePlayer()
    }

    var isPictureInPictureSupported: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    @discardableResult
    func play(_ video: Video) -> AVPlayer? {
        guard let remoteURL = video.fullVideoURL else {
            error = L10n.videoPlayFailed
            return nil
        }
        activateAudioSession()

        if activeVideo?.id == video.id, currentRemoteURL == remoteURL,
           player.currentItem != nil {
            activeVideo = video
            player.play()
            return player
        }

        releaseItem()
        let localURL = cache.cachedFile(for: remoteURL)
        let item = makeItem(url: localURL ?? remoteURL, remoteURL: remoteURL)
        player.replaceCurrentItem(with: item)
        observe(item)
        activeVideo = video
        currentRemoteURL = remoteURL
        error = nil
        player.play()

        if localURL == nil {
            prefetchIfNeeded(video: video, remoteURL: remoteURL)
        }
        return player
    }

    func setDetailVisible(_ visible: Bool) {
        detailVisible = visible
    }

    func togglePlayPause() {
        guard player.currentItem != nil else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else if player.currentItem?.status == .readyToPlay,
                  player.currentTime() >= (player.currentItem?.duration ?? .zero) {
            player.seek(to: .zero)
            player.play()
        } else {
            player.play()
        }
    }

    func pause() {
        player.pause()
    }

    func resume() {
        player.play()
    }

    func seek(by seconds: Double) {
        let target = player.currentTime().seconds + seconds
        seek(to: target)
    }

    func seek(to seconds: Double) {
        guard seconds.isFinite, seconds >= 0 else { return }
        let duration = player.currentItem?.duration.seconds ?? 0
        let clamped = duration.isFinite && duration > 0
            ? min(seconds, duration)
            : seconds
        player.seek(
            to: CMTime(seconds: clamped, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    func close() {
        retryTask?.cancel()
        retryTask = nil
        releaseItem()
        activeVideo = nil
        currentRemoteURL = nil
        error = nil
        deactivateAudioSession()
    }

    // MARK: - Picture in Picture

    func attach(_ controller: AVPictureInPictureController) {
        controller.delegate = self
        pipController = controller
        controller.canStartPictureInPictureAutomaticallyFromInline = true
    }

    func detach(_ controller: AVPictureInPictureController) {
        if pipController === controller {
            pipController = nil
        }
    }

    func startPictureInPicture() {
        guard let pipController, pipController.isPictureInPicturePossible else {
            error = L10n.videoPipUnavailable
            return
        }
        pipController.startPictureInPicture()
    }

    func stopPictureInPicture() {
        pipController?.stopPictureInPicture()
    }

    // MARK: - Player observations

    private func observePlayer() {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                self?.isPlaying = player.timeControlStatus == .playing
                self?.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isPlaying = false }
        }
        failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor in self?.handleFailure(error) }
        }
    }

    private func observe(_ item: AVPlayerItem) {
        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor in self?.handleFailure(item.error) }
        }
    }

    private func makeItem(url: URL, remoteURL: URL) -> AVPlayerItem {
        let options: [String: Any]?
        if url == remoteURL, let token = tokenProvider(), !token.isEmpty {
            options = ["AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Bearer \(token)"]]
        } else {
            options = nil
        }
        let asset = AVURLAsset(url: url, options: options)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 10
        return item
    }

    private func prefetchIfNeeded(video: Video, remoteURL: URL) {
        guard !networkMonitor.isExpensive else { return }
        guard video.fileSize.map({ $0 <= 100 * 1024 * 1024 }) ?? true else { return }
        let token = tokenProvider()
        Task { [cache] in
            await cache.prefetch(
                url: remoteURL,
                token: token,
                expectedSize: video.fileSize
            )
        }
    }

    private func handleFailure(_ failure: Error?) {
        guard let remoteURL = currentRemoteURL else { return }
        if let failure, (failure as NSError).code == NSURLErrorCancelled { return }

        // Битый локальный файл не должен ломать каждый следующий запуск.
        cache.remove(for: remoteURL)
        retryTask?.cancel()
        isBuffering = true
        let position = player.currentTime()

        retryTask = Task { [weak self] in
            guard let self else { return }
            for _ in 0..<Self.retryAttempts {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: Self.retryDelay)
                guard self.networkMonitor.isOnline else { continue }
                let item = self.makeItem(url: remoteURL, remoteURL: remoteURL)
                self.player.replaceCurrentItem(with: item)
                self.observe(item)
                await self.player.seek(to: position)
                self.player.play()
                self.isBuffering = false
                self.error = nil
                return
            }
            self.isBuffering = false
            self.error = L10n.videoPlayFailed
        }
    }

    private func releaseItem() {
        itemStatusObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        isBuffering = false
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
    }
}

extension VideoPlaybackManager: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor in
            self.isPictureInPictureActive = true
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor in
            self.isPictureInPictureActive = false
        }
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        Task { @MainActor in
            self.isPictureInPictureActive = false
            self.error = error.localizedDescription
        }
    }
}
