import SwiftUI
import UIKit

/// Кнопка отправки с зарядом: короткий тап отправляет сразу, удержание копит
/// силу 0...100, свайп вверх/влево отменяет отправку.
struct ChargeSendButton: View {
    let isEnabled: Bool
    let icon: String
    let onSend: (Int) -> Void

    @State private var startedAt: Date?
    @State private var power = 0
    @State private var cancelled = false
    @State private var ticker: Task<Void, Never>?
    @State private var lastHaptic = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(power) / 100)
                .stroke(
                    cancelled ? Color.red : Color.accentColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            if power > 0 {
                Text(cancelled ? "×" : "\(power)")
                    .font(.caption2).bold()
                    .foregroundColor(cancelled ? .red : .accentColor)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
        }
        .frame(width: 38, height: 38)
        .frame(width: 44, height: 44)
        .opacity(isEnabled ? 1 : 0.35)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    startIfNeeded()
                    cancelled = ChargeCalculator.isCancelled(
                        translationY: value.translation.height
                    )
                }
                .onEnded { _ in finish() }
        )
        .onDisappear {
            ticker?.cancel()
            ticker = nil
        }
    }

    private func startIfNeeded() {
        guard startedAt == nil else { return }
        startedAt = Date()
        cancelled = false
        power = 0
        lastHaptic = 0
        ticker = Task { @MainActor in
            while !Task.isCancelled {
                if let startedAt {
                    power = ChargeCalculator.power(elapsed: Date().timeIntervalSince(startedAt))
                    let level = ChargeCalculator.hapticLevel(power: power)
                    if level > lastHaptic {
                        lastHaptic = level
                        Haptics.impact(.light)
                    }
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
    }

    private func finish() {
        ticker?.cancel()
        ticker = nil
        let elapsed = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        let finalPower = ChargeCalculator.power(elapsed: elapsed)
        let wasCancelled = cancelled || !isEnabled
        startedAt = nil
        power = 0
        cancelled = false
        guard !wasCancelled else {
            Haptics.warning()
            return
        }
        Haptics.impact(.medium)
        // До секунды удержания — обычное сообщение без заряда, как на Android.
        onSend(ChargeCalculator.isCharged(elapsed: elapsed) ? finalPower : 0)
    }
}
