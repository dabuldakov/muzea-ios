import Foundation

/// Единое состояние ленты видео.
struct VideoFeedUiState: Equatable {
    var videos: [VideoResponse] = []
    var isLoading = false
    var error: String?
}

@MainActor
final class VideoListViewModel: ObservableObject {
    @Published private(set) var state = VideoFeedUiState()

    private let repository: VideoRepository
    private let ownUsername: String?

    init(repository: VideoRepository, ownUsername: String?) {
        self.repository = repository
        self.ownUsername = ownUsername
        // Сначала отдаём кэш, чтобы вкладка показалась мгновенно.
        state.videos = VideoFeedFilter.filter(repository.cachedVideos(), ownUsername: ownUsername)
    }

    func load() async {
        if state.videos.isEmpty { state.isLoading = true }
        do {
            let all = try await repository.getVideos()
            state.videos = VideoFeedFilter.filter(all, ownUsername: ownUsername)
            state.error = nil
        } catch {
            state.error = error.localizedDescription
        }
        state.isLoading = false
    }

    func consumeError() {
        state.error = nil
    }
}
