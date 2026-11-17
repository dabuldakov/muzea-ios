import AVFoundation
import Foundation

/// Длительность аудиофайла для карточки вложения. Отдельно от видеоподготовки:
/// аудио не требует миниатюры, но без длительности пузырь выглядит пустым.
enum AudioPreparation {
    static func durationSeconds(data: Data, fileName: String) async -> Int? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio-prep-\(UUID().uuidString)-\(fileName)")
        guard (try? data.write(to: url, options: .atomic)) != nil else { return nil }
        defer { try? FileManager.default.removeItem(at: url) }

        let asset = AVURLAsset(url: url)
        guard let seconds = try? await asset.load(.duration).seconds,
              seconds.isFinite,
              seconds > 0 else { return nil }
        return Int(seconds.rounded())
    }
}
