import UIKit

/// Кэш картинок вложений: пузыри не должны скачивать одно и то же при каждой
/// перерисовке. Ключ включает uuid и вариант (preview/full).
final class AttachmentImageCache {
    static let shared = AttachmentImageCache()
    private let cache = NSCache<NSString, UIImage>()

    func cached(key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func store(_ image: UIImage, key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    func clear() {
        cache.removeAllObjects()
    }
}

/// Вложения в пузыре: сетка фото, видео, аудио и документы. Каждый тип — свой
