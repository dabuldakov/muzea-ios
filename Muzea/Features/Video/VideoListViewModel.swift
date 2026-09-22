import Foundation

@MainActor
final class VideoListViewModel: ObservableObject {
    @Published var videos: [VideoResponse] = []
    @Published var isLoading = false
    @Published var error: String?

    private let repository: VideoRepository
    private let ownUsername: String?

    init(repository: VideoRepository, ownUsername: String?) {
        self.repository = repository
        self.ownUsername = ownUsername
    }

    func load() async {
        isLoading = true
        do {
            let all = try await repository.getVideos()
            videos = VideoFeedFilter.filter(all, ownUsername: ownUsername)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
