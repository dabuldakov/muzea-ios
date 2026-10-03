import Foundation

@MainActor
final class VideoDetailViewModel: ObservableObject {
    @Published private(set) var isDeleting = false
    @Published private(set) var error: String?

    private let repository: VideoRepository

    init(repository: VideoRepository) {
        self.repository = repository
    }

    func delete(id: Int64) async -> Bool {
        isDeleting = true
        defer { isDeleting = false }
        do {
            error = nil
            try await repository.deleteVideo(id)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
