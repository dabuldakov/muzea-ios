import Combine
import Foundation

@MainActor
final class NewsDetailViewModel: ObservableObject {
    @Published private(set) var news: News?
    @Published private(set) var comments: [NewsComment] = []
    @Published private(set) var commentsTotal: Int64 = 0
    @Published private(set) var hasMoreComments = false
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingComments = false
    @Published private(set) var isSending = false
    @Published private(set) var isDeleting = false
    @Published private(set) var error: String?

    private let repository: NewsRepository
    private let likeStore: NewsLikeStore
    private var likeCancellable: AnyCancellable?
    private var newsId: Int64 = 0
    private var nextBefore: Int64?
    private var viewRegistered = false

    private let commentsPageSize = 20

    init(repository: NewsRepository, likeStore: NewsLikeStore? = nil) {
        self.repository = repository
        let store = likeStore ?? NewsLikeStore(repository: repository)
        self.likeStore = store
        likeCancellable = store.$states.sink { [weak self] _ in
            self?.applyLikeState()
        }
    }

    private func applyLikeState() {
        guard let current = news else { return }
        let updated = likeStore.apply(current)
        if updated != current {
            news = updated
        }
    }

    func load(id: Int64) async {
        guard newsId != id || news == nil else { return }
        newsId = id
        await reload()
        if !viewRegistered {
            viewRegistered = true
            await repository.registerNewsView(id)
        }
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await repository.getNewsById(newsId)
            news = likeStore.apply(loaded)
            error = nil
        } catch {
            self.error = error.localizedDescription
            return
        }
        await loadComments()
    }

    func loadComments() async {
        guard !isLoadingComments else { return }
        isLoadingComments = true
        defer { isLoadingComments = false }
        do {
            let page = try await repository.getNewsComments(
                newsId,
                before: nil,
                size: commentsPageSize
            )
            comments = page.comments
            commentsTotal = page.total
            hasMoreComments = page.hasMore
            nextBefore = page.nextBefore
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadOlderComments() async {
        guard hasMoreComments, !isLoadingComments, let cursor = nextBefore else { return }
        isLoadingComments = true
        defer { isLoadingComments = false }
        do {
            let page = try await repository.getNewsComments(
                newsId,
                before: cursor,
                size: commentsPageSize
            )
            let merged = Dictionary(
                (page.comments + comments).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            ).values.sorted { $0.id < $1.id }
            comments = merged
            commentsTotal = page.total
            hasMoreComments = page.hasMore
            nextBefore = page.nextBefore
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addComment(_ text: String) async -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !isSending else { return false }
        isSending = true
        defer { isSending = false }
        do {
            let comment = try await repository.addNewsComment(newsId, content: value)
            if !comments.contains(where: { $0.id == comment.id }) {
                comments.append(comment)
                comments.sort { $0.id < $1.id }
                commentsTotal += 1
            }
            error = nil
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func deleteComment(_ comment: NewsComment) async {
        do {
            try await repository.deleteNewsComment(newsId, commentId: comment.id)
            comments.removeAll { $0.id == comment.id }
            commentsTotal = max(0, commentsTotal - 1)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleLike() async {
        guard let current = news else { return }
        if let error = await likeStore.toggle(current) {
            self.error = error
        }
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

    func consumeError() {
        error = nil
    }
}
