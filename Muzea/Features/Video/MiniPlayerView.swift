import AVFoundation
import Combine
import SwiftUI

/// Плавающий mini-плеер поверх вкладок. Повторяет поведение Android:
/// play/pause, ±10 секунд, перемотка, закрытие и перетаскивание.
struct MiniPlayerView: View {
    @ObservedObject var playback: VideoPlaybackManager
    var onOpen: ((Video) -> Void)?

    @State private var center: CGPoint?
    @State private var dragStart: CGPoint?
    @State private var progress: Double = 0
    @State private var duration: Double = 0
    @State private var scrubValue: Double = 0
    @State private var isScrubbing = false
    @State private var didRestorePosition = false

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    private let cardWidth: CGFloat = 236
    private let cardHeight: CGFloat = 232

    @ViewBuilder
    var body: some View {
        if let video = playback.activeVideo,
           !playback.detailVisible,
           !playback.isPictureInPictureActive {
            card(video: video)
                .frame(width: cardWidth, height: cardHeight)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                .position(center ?? defaultCenter)
                .gesture(dragGesture)
                .onAppear {
                    restorePositionIfNeeded()
                    updateProgress()
                }
                .onReceive(timer) { _ in updateProgress() }
                .onChange(of: playback.activeVideo?.id) { _ in
                    updateProgress()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityElement(children: .contain)
        }
    }

    private func card(video: Video) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(video.title)
                    .font(.caption).bold()
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button {
                    playback.close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption).bold()
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.close)
            }

            VideoPlayerSurface(
                player: playback.player,
                gravity: .resizeAspectFill,
                playback: playback
            )
            .frame(height: 112)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { onOpen?(video) }
            .accessibilityLabel(L10n.videoPlay)

            HStack(spacing: 14) {
                Button { playback.seek(by: -10) } label: {
                    Image(systemName: "gobackward.10")
                }
                .accessibilityLabel(L10n.videoReplay10)

                Button { playback.togglePlayPause() } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 22)
                }
                .accessibilityLabel(playback.isPlaying ? L10n.pause : L10n.videoPlay)

                Button { playback.seek(by: 10) } label: {
                    Image(systemName: "goforward.10")
                }
                .accessibilityLabel(L10n.videoForward10)

                Spacer(minLength: 0)

                if playback.isPictureInPictureSupported {
                    Button { playback.startPictureInPicture() } label: {
                        Image(systemName: "pip.enter")
                    }
                    .accessibilityLabel(L10n.videoPip)
                }
            }
            .buttonStyle(.plain)
            .font(.body)

            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubValue : progress },
                    set: { scrubValue = $0 }
                ),
                in: 0...max(duration, 0.1),
                onEditingChanged: { editing in
                    if editing {
                        scrubValue = progress
                        isScrubbing = true
                    } else {
                        playback.seek(to: scrubValue)
                        isScrubbing = false
                    }
                }
            )
            .tint(.accentColor)
            .accessibilityLabel(L10n.videoSeek)
        }
        .padding(8)
    }

    private var defaultCenter: CGPoint {
        let bounds = UIScreen.main.bounds
        return CGPoint(
            x: bounds.maxX - cardWidth / 2 - 12,
            y: bounds.maxY - cardHeight / 2 - 96
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = center ?? defaultCenter
                }
                guard let start = dragStart else { return }
                center = CGPoint(
                    x: start.x + value.translation.width,
                    y: start.y + value.translation.height
                )
            }
            .onEnded { _ in
                dragStart = nil
                clampPosition()
                persistPosition()
            }
    }

    private func restorePositionIfNeeded() {
        guard !didRestorePosition else { return }
        didRestorePosition = true
        let defaults = UserDefaults.standard
        let x = defaults.double(forKey: "video.mini.x")
        let y = defaults.double(forKey: "video.mini.y")
        if x > 0, y > 0 {
            center = CGPoint(x: x, y: y)
            clampPosition()
        } else {
            center = defaultCenter
        }
    }

    private func clampPosition() {
        guard let current = center else { return }
        let bounds = UIScreen.main.bounds
        let minX = cardWidth / 2 + 8
        let maxX = bounds.maxX - cardWidth / 2 - 8
        let minY = cardHeight / 2 + 56
        let maxY = bounds.maxY - cardHeight / 2 - 72
        center = CGPoint(
            x: min(max(current.x, minX), maxX),
            y: min(max(current.y, minY), maxY)
        )
    }

    private func persistPosition() {
        guard let center else { return }
        let defaults = UserDefaults.standard
        defaults.set(center.x, forKey: "video.mini.x")
        defaults.set(center.y, forKey: "video.mini.y")
    }

    private func updateProgress() {
        guard let item = playback.player.currentItem else {
            progress = 0
            duration = 0
            return
        }
        let itemDuration = item.duration.seconds
        duration = itemDuration.isFinite && itemDuration > 0 ? itemDuration : 0
        let current = playback.player.currentTime().seconds
        if !isScrubbing, current.isFinite, current >= 0 {
            progress = current
        }
    }
}
