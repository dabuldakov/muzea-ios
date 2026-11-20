import SwiftUI

/// Картинка на всю ширину контейнера с фиксированной высотой.
///
/// `scaledToFill()` + `.frame(height:)` без явной ширины берёт натуральную
/// ширину изображения: горизонтальный кадр 16:9 при высоте 180–240 pt
/// оказывается шире экрана. `GeometryReader` передаёт точную ширину, поэтому
/// картинка всегда обрезается по границам экрана.
///
/// Загрузка идёт через `RemoteImageCache`: memory + диск, как Glide на Android.
struct FullWidthImage: View {
    let url: URL?
    let height: CGFloat
    var placeholderIcon: String = "newspaper"

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color(.tertiarySystemBackground)
                        Image(systemName: placeholderIcon)
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: width, height: height)
            .clipped()
            .task(id: "\(url?.absoluteString ?? "")|\(Int(width))") {
                image = nil
                guard let url, width > 0 else { return }
                let loaded = await RemoteImageCache.shared.image(
                    for: url,
                    maxPixelSize: width * UIScreen.main.scale
                )
                guard !Task.isCancelled else { return }
                image = loaded
            }
        }
        .frame(height: height)
    }
}
