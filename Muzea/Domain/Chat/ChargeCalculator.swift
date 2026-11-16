import Foundation

/// Расчёт «заряда» кнопки отправки и порога отмены свайпом. Чистая логика,
/// чтобы поведение покрывалось тестами без UIKit.
enum ChargeCalculator {
    /// Полная шкала — минута удержания, как на Android.
    static let maxDuration: TimeInterval = 60
    /// Сдвиг пальца, после которого отправка отменяется.
    static let cancelThreshold: Double = 60

    static func power(elapsed: TimeInterval) -> Int {
        guard elapsed > 0 else { return 0 }
        let value = Int((elapsed / maxDuration * 100).rounded(.down))
        return min(max(value, 0), 100)
    }

    static func isCancelled(translationX: Double, translationY: Double) -> Bool {
        translationX < -cancelThreshold || translationY < -cancelThreshold
    }

    /// Ближайшая ступень вибрации: 25/50/75/100.
    static func hapticLevel(power: Int) -> Int {
        min(power / 25, 4)
    }
}
