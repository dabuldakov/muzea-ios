import Foundation

@MainActor
final class CreateNewsViewModel: ObservableObject {
    @Published private(set) var ownVideos: [Video] = []
    @Published private(set) var isSubmitting = false
    @Published private(set) var error: String?

    private let newsRepository: NewsRepository
    private let videoRepository: VideoRepository
    private let news: News?

    init(newsRepository: NewsRepository, videoRepository: VideoRepository, news: News? = nil) {
        self.newsRepository = newsRepository
        self.videoRepository = videoRepository
        self.news = news
    }

    /// Список своих видео для необязательной привязки к новости.
    func loadVideos(ownUsername: String?) async {
        guard let ownUsername, !ownUsername.isEmpty else { return }
        let all = (try? await videoRepository.getVideos()) ?? []
        ownVideos = VideoFeedFilter.filter(all, ownUsername: ownUsername)
    }

    func submit(
        title: String,
        content: String,
        videoId: Int64?,
        image: UploadFile?,
        removeImage: Bool = false
    ) async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            error = nil
            if let news {
                _ = try await newsRepository.updateNews(
                    id: news.id,
                    title: title,
                    content: content,
                    videoId: videoId,
                    removeVideo: videoId == nil && news.relatedVideo != nil,
                    image: image,
                    removeImage: removeImage
                )
            } else {
                _ = try await newsRepository.createNews(
                    title: title,
                    content: content,
                    videoId: videoId,
                    image: image
                )
            }
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
