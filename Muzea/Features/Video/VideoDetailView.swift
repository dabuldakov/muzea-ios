import SwiftUI
import AVKit

struct VideoDetailView: View {
    let video: VideoResponse

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let url = video.fullVideoURL {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 220)
                        .cornerRadius(8)
                }

                Text(video.title).font(.title3).bold()

                if let description = video.description, !description.isEmpty {
                    Text(description)
                }

                HStack {
                    Text("Автор: \(video.uploadedBy)")
                    Spacer()
                    Text("\(video.views) просмотров")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Видео")
        .navigationBarTitleDisplayMode(.inline)
    }
}
