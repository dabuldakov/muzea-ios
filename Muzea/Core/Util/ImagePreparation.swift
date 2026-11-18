import Foundation
import ImageIO
import UIKit

/// Подготовка изображений к отправке: downscale до 2048 px и JPEG.
/// Использует ImageIO thumbnail, чтобы не декодировать 50-мегапиксельные фото
/// в полном размере (иначе легко получить сотни мегабайт памяти).
enum ImagePreparation {
    static let maxDimension: CGFloat = 2048
    static let jpegQuality: CGFloat = 0.82

    struct Prepared {
        let data: Data
        let width: Int
        let height: Int
    }

    /// Синхронная версия для тестов и фоновых задач.
    static func jpeg(from data: Data) -> Prepared? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            return nil
        }
        let image = UIImage(cgImage: cgImage)
        guard let jpeg = image.jpegData(compressionQuality: jpegQuality) else {
            return nil
        }
        return Prepared(data: jpeg, width: cgImage.width, height: cgImage.height)
    }

    /// Асинхронная версия для UI: декодирование не блокирует главный поток.
    static func jpegAsync(from data: Data) async -> Prepared? {
        await Task.detached(priority: .userInitiated) {
            jpeg(from: data)
        }.value
    }
}
