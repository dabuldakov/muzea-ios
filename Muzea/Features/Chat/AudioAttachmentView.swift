import SwiftUI
import UIKit

// MARK: - Audio

struct AudioAttachmentView: View {
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
                        Text(attachment.fileName ?? L10n.voiceFallback)
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
        .accessibilityLabel(isPlaying ? L10n.pause : L10n.playVoice)
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
        return Waveform.barHeight(level: level, totalHeight: height)
    }
}
