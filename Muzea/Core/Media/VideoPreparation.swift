import AVFoundation
import UIKit

/// Подготовка видео к отправке: миниатюра по кадру, размеры кадра и
/// длительность. Отдельный тип, чтобы View не работал с AVFoundation напрямую.
enum VideoPreparation {
    struct Prepared {
        let thumbnail: Data?
        let width: Int?
        let height: Int?
        let duration: Int?
    }

    /// Миниатюра нужна только для пузыря, поэтому не больше 480 px по стороне.
    static let thumbnailMaxSide: CGFloat = 480

    static func prepare(data: Data, fileName: String) async -> Prepared {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("video-prep-\(UUID().uuidString)-\(fileName)")
        guard (try? data.write(to: url, options: .atomic)) != nil else {
            return Prepared(thumbnail: nil, width: nil, height: nil, duration: nil)
        }
        defer { try? FileManager.default.removeItem(at: url) }

        let asset = AVURLAsset(url: url)
        let duration = (try? await asset.load(.duration).seconds)
            .map { Int($0.rounded()) }

        var width: Int?
        var height: Int?
        if let track = try? await asset.loadTracks(withMediaType: .video).first,
           let size = try? await track.load(.naturalSize) {
            width = Int(abs(size.width).rounded())
            height = Int(abs(size.height).rounded())
        }

        let thumbnail = await thumbnailData(asset: asset)
        return Prepared(
            thumbnail: thumbnail,
            width: width,
            height: height,
            duration: duration
        )
    }

    private static func thumbnailData(asset: AVAsset) async -> Data? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(
            width: thumbnailMaxSide,
            height: thumbnailMaxSide
        )
        // Первый кадр часто чёрный (заставка), берём немного позже.
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        guard let cgImage = try? await generator.image(at: time).image else {
            return nil
        }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.8)
    }
}
