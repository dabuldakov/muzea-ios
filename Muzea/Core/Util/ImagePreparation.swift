import UIKit

/// Подготовка фото к отправке: JPEG, ограничение длинной стороны и сжатие.
/// HEIC и другие форматы галереи приводим к JPEG, который разрешён сервером.
enum ImagePreparation {
    static let maxDimension: CGFloat = 2048
    static let jpegQuality: CGFloat = 0.82

    struct Prepared {
        let data: Data
        let width: Int
        let height: Int
    }

    static func jpeg(from data: Data) -> Prepared? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            return nil
        }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / longest)
        let target = CGSize(
            width: max(1, (image.size.width * scale).rounded()),
            height: max(1, (image.size.height * scale).rounded())
        )

        let rendered: UIImage
        if scale < 1 {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: target))
            }
        } else {
            rendered = image
        }

        guard let jpeg = rendered.jpegData(compressionQuality: jpegQuality) else { return nil }
        return Prepared(
            data: jpeg,
            width: Int(target.width),
            height: Int(target.height)
        )
    }
}
