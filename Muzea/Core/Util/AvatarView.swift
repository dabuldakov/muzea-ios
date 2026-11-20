import SwiftUI

struct AvatarView: View {
    let url: URL?
    var size: CGFloat = 44

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: url) {
            image = nil
            guard let url else { return }
            let maxPixel = size * UIScreen.main.scale
            let loaded = await RemoteImageCache.shared.image(for: url, maxPixelSize: maxPixel)
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }
}
