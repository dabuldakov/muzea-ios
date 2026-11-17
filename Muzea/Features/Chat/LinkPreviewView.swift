import SwiftUI

/// Карточка Open Graph под текстом сообщения. Пока превью грузится или сайт
/// недоступен, не занимает место.
struct LinkPreviewView: View {
    let url: URL

    @State private var preview: LinkPreview?

    var body: some View {
        Group {
            if let preview {
                Link(destination: preview.url) {
                    HStack(alignment: .top, spacing: 10) {
                        if let imageURL = preview.imageURL {
                            AsyncImage(url: imageURL) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().scaledToFill()
                                } else {
                                    Color(.tertiarySystemBackground)
                                }
                            }
                            .frame(width: 64, height: 64)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            if let site = preview.siteName, !site.isEmpty {
                                Text(site.uppercased())
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            if let title = preview.title, !title.isEmpty {
                                Text(title)
                                    .font(.footnote).bold()
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                            }
                            if let description = preview.description, !description.isEmpty {
                                Text(description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .frame(maxWidth: 260, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: url) {
            preview = await LinkPreviewService.shared.load(url)
        }
    }
}
