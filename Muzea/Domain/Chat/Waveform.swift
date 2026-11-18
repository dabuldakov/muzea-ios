import Foundation

/// Волна голосового сообщения: нормализация пиков в столбцы фиксированной
/// ширины. Чистая функция без AVFoundation — её можно тестировать без файлов
/// и устройства.
enum Waveform {
    static let defaultBarCount = 32
    /// Минимальная высота столбца: тишина всё равно должна читаться как волна.
    static let minimumLevel = 0.12

    /// Прореживает амплитуды до `count` столбцов, нормирует по максимуму и
    /// сжимает корнем — тихая речь остаётся различимой.
    static func downsample(_ samples: [Float], count: Int = defaultBarCount) -> [Double] {
        guard count > 0 else { return [] }
        let silence = Array(repeating: minimumLevel, count: count)
        guard !samples.isEmpty else { return silence }

        let peak = samples.reduce(Float(0)) { partial, sample in
            sample.isFinite ? max(partial, abs(sample)) : partial
        }
        guard peak > 0 else { return silence }

        return (0..<count).map { bar in
            let start = samples.count * bar / count
            let end = max(start + 1, samples.count * (bar + 1) / count)
            var value: Float = 0
            for index in start..<min(end, samples.count) {
                let sample = samples[index]
                guard sample.isFinite else { continue }
                value = max(value, abs(sample))
            }
            let normalized = Double(value / peak).squareRoot()
            return min(1, max(minimumLevel, normalized))
        }
    }

    /// Высота столбца в точках: не меньше 3 pt, чтобы тишина читалась.
    static func barHeight(level: Double, totalHeight: CGFloat) -> CGFloat {
        let clamped = min(1, max(0, level))
        return max(3, totalHeight * CGFloat(clamped))
    }

    /// Доля проигранных столбцов для текущего прогресса 0...1.
    static func playedCount(total: Int, progress: Double) -> Int {
        guard total > 0 else { return 0 }
        let clamped = min(1, max(0, progress))
        return Int((Double(total) * clamped).rounded(.down))
    }
}
