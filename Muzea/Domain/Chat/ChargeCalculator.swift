import Foundation

/// Расчёт «заряда» кнопки отправки и порога отмены свайпом — как на Android.
/// До 1 секунды удержание считается обычной отправкой; дальше сила растёт по
/// `sqrt`, иначе первые секунды почти не видны, а к концу шкала прыгает.
enum ChargeCalculator {
    static let minHold: TimeInterval = 1
    static let maxHold: TimeInterval = 60
    /// Свайп вверх, после которого отправка отменяется (72dp на Android).
    static let cancelThreshold: Double = 72

    static func power(elapsed: TimeInterval) -> Int {
        guard elapsed > minHold else { return 0 }
        if elapsed >= maxHold { return 100 }
        let level = (elapsed - minHold) / (maxHold - minHold)
        return min(max(Int((level.squareRoot() * 100).rounded()), 0), 100)
    }

    static func isCharged(elapsed: TimeInterval) -> Bool {
        elapsed >= minHold
    }

    static func isCancelled(translationY: Double) -> Bool {
        translationY < -cancelThreshold
    }

    /// Ближайшая ступень вибрации: 25/50/75/100.
    static func hapticLevel(power: Int) -> Int {
        min(power / 25, 4)
    }
}
