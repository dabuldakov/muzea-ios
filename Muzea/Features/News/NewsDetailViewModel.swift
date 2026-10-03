import Foundation

@MainActor
final class NewsDetailViewModel: ObservableObject {
    @Published private(set) var news: NewsResponse?
    @Published private(set) var isLoading = false
    @Published private(set) var isDeleting = false
    @Published private(set) var error: String?

    private let repository: NewsRepository

    init(repository: NewsRepository) {
        self.repository = repository
    }

    func load(id: Int64) async {
        isLoading = true
        do {
            news = try await repository.getNewsById(id)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func delete(id: Int64) async -> Bool {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await repository.deleteNews(id)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
