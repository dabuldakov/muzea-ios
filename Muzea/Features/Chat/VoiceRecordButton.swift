import SwiftUI
import UIKit

/// Кнопка записи голосового: удержание пишет, отпускание отправляет, свайп
/// вверх отменяет. Показывает длительность и красную индикацию отмены.
struct VoiceRecordButton: View {
    let onRecorded: (RecordedVoice) -> Void
    let onError: (String) -> Void

    @State private var recorder: VoiceRecorder?
    @State private var isRecording = false
    @State private var startedAt: Date?
    @State private var elapsed = 0
    @State private var cancelled = false
    @State private var ticker: Task<Void, Never>?

    var body: some View {
        ZStack {
            Circle()
                .fill(cancelled ? Color.red.opacity(0.2) : Color.accentColor.opacity(0.12))
            if isRecording {
                Text(cancelled ? "×" : DurationFormatter.mmss(elapsed))
                    .font(.caption2).bold()
                    .foregroundColor(cancelled ? .red : .accentColor)
            } else {
                Image(systemName: "mic.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .frame(width: Theme.Size.iconButton, height: Theme.Size.iconButton)
        .contentShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRecording ? "Идёт запись" : "Записать голосовое")
        .accessibilityValue(isRecording ? DurationFormatter.mmss(elapsed) : "")
        .accessibilityHint("Удерживайте для записи, свайп вверх — отмена")
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if startedAt == nil { start() }
                    if isRecording {
                        cancelled = ChargeCalculator.isCancelled(
                            translationY: value.translation.height
                        )
                    }
                }
                .onEnded { _ in finish() }
        )
        .onDisappear { cancel() }
    }

    private func start() {
        startedAt = Date()
        elapsed = 0
        cancelled = false
        Task {
            let granted = await VoiceRecorder.requestPermission()
            guard granted else {
                reset()
                onError("Нет доступа к микрофону. Разрешите его в настройках.")
                return
            }
            guard startedAt != nil else { return }
            let recorder = VoiceRecorder()
            guard recorder.start() else {
                reset()
                onError("Не удалось начать запись")
                return
            }
            self.recorder = recorder
            isRecording = true
            ticker = Task { @MainActor in
                while !Task.isCancelled, isRecording {
                    elapsed = Int(Date().timeIntervalSince(startedAt ?? Date()))
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }
        }
    }

    private func finish() {
        ticker?.cancel()
        ticker = nil
        guard let recorder else {
            reset()
            return
        }
        let wasCancelled = cancelled
        let recorded = recorder.stop()
        reset()
        if wasCancelled || recorded == nil {
            return
        }
        if let recorded {
            onRecorded(recorded)
        }
    }

    private func cancel() {
        ticker?.cancel()
        ticker = nil
        recorder?.cancel()
        reset()
    }

    private func reset() {
        recorder = nil
        startedAt = nil
        isRecording = false
        elapsed = 0
        cancelled = false
    }
}
