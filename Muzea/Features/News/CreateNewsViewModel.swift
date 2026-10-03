import Foundation

@MainActor
final class CreateNewsViewModel: ObservableObject {
    @Published private(set) var ownVideos: [VideoResponse] = []
    @Published private(set) var isSubmitting = false
    @Published private(set) var error: String?

    private let newsRepository: NewsRepository
    private let videoRepository: VideoRepository

    init(newsRepository: NewsRepository, videoRepository: VideoRepository) {
        self.newsRepository = newsRepository
        self.videoRepository = videoRepository
    }

    /// Список своих видео для необязательной привязки к новости.
    func loadVideos(ownUsername: String?) async {
        guard let ownUsername, !ownUsername.isEmpty else { return }
        let all = (try? await videoRepository.getVideos()) ?? []
        ownVideos = VideoFeedFilter.filter(all, ownUsername: ownUsername)
    }

    func submit(title: String, content: String, videoId: Int64?, image: UploadFile?) async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            error = nil
            _ = try await newsRepository.createNews(
                title: title,
                content: content,
                videoId: videoId,
                image: image
            )
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func consumeError() {
        error = nil
    }
}
