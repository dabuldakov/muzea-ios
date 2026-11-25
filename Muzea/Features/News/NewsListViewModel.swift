import Foundation

/// Единое состояние ленты новостей.
struct NewsFeedUiState: Equatable {
    var news: [News] = []
    var isLoading = false
    var isRefreshing = false
    var endReached = false
    var error: String?
}

@MainActor
final class NewsListViewModel: ObservableObject {
    @Published private(set) var state = NewsFeedUiState()

    private let newsRepository: NewsRepository
    private let contactRepository: ContactRepository
    private let ownUsername: String?
    private let pageSize = Config.newsPageSize

    private var raw: [News] = []
    private var contactUsernames: Set<String> = []
    private var contactsLoaded = false
    private var page = 0
    private var endReached = false
    private var isLoading = false

    init(newsRepository: NewsRepository, contactRepository: ContactRepository, ownUsername: String?) {
        self.newsRepository = newsRepository
        self.contactRepository = contactRepository
        self.ownUsername = ownUsername
    }

    func load(reset: Bool = true) async {
        guard !isLoading else { return }
        isLoading = true

        if reset {
            raw = []
            page = 0
            endReached = false
            // Список контактов мог измениться с прошлого обновления.
            contactsLoaded = false
            state.isRefreshing = !state.news.isEmpty
            state.news = []
        }
        state.isLoading = state.news.isEmpty
        state.error = nil

        do {
            if !contactsLoaded {
                contactsLoaded = true
                await loadContactUsernames()
            }

            var iterations = 0
            repeat {
                let response = try await newsRepository.getNews(page: page, size: pageSize)
                let items = response.content
                if items.isEmpty {
                    endReached = true
                } else {
                    raw.append(contentsOf: items)
                    page += 1
                    if items.count < pageSize { endReached = true }
                }
                state.news = NewsFeedFilter.filter(raw, contactUsernames: contactUsernames, ownUsername: ownUsername)
                iterations += 1
            } while !endReached && state.news.count < pageSize && iterations < 10

            if let liked = try? await newsRepository.likedNewsIds() {
                applyLikedIds(liked)
            }
            state.error = nil
        } catch {
            state.error = error.localizedDescription
        }

        state.isLoading = false
        state.isRefreshing = false
        state.endReached = endReached
        isLoading = false
    }

    func loadMoreIfNeeded(currentItem: News) async {
        guard !endReached, !isLoading else { return }
        guard let index = state.news.firstIndex(of: currentItem), index >= state.news.count - 2 else { return }
        await load(reset: false)
    }

    /// Оптимистичный лайк: сервер подтверждает количество, при ошибке откат.
    func toggleLike(_ id: Int64) async {
        guard let index = state.news.firstIndex(where: { $0.id == id }) else { return }
        let current = state.news[index]
        let target = !current.likedByMe
        updateLike(id: id, liked: target, likes: current.likes + (target ? 1 : -1))

        do {
            let likes = target
                ? try await newsRepository.likeNews(id)
                : try await newsRepository.unlikeNews(id)
            updateLike(id: id, liked: target, likes: likes)
        } catch {
            updateLike(id: id, liked: current.likedByMe, likes: current.likes)
            state.error = error.localizedDescription
        }
    }

    private func updateLike(id: Int64, liked: Bool, likes: Int64) {
        let normalized = max(0, likes)
        if let rawIndex = raw.firstIndex(where: { $0.id == id }) {
            raw[rawIndex].likedByMe = liked
            raw[rawIndex].likes = normalized
        }
        if let index = state.news.firstIndex(where: { $0.id == id }) {
            state.news[index].likedByMe = liked
            state.news[index].likes = normalized
        }
    }

    private func applyLikedIds(_ ids: Set<Int64>) {
        for index in raw.indices {
            raw[index].likedByMe = ids.contains(raw[index].id)
        }
        for index in state.news.indices {
            state.news[index].likedByMe = ids.contains(state.news[index].id)
        }
    }

    func delete(_ item: News) async -> Bool {
        do {
            try await newsRepository.deleteNews(item.id)
            raw.removeAll { $0.id == item.id }
            state.news.removeAll { $0.id == item.id }
            return true
        } catch {
            state.error = error.localizedDescription
            return false
        }
    }

    func consumeError() {
        state.error = nil
    }

    private func loadContactUsernames() async {
        guard let contacts = try? await contactRepository.loadContacts() else { return }
        contactUsernames = Set(
            contacts
                .compactMap { ($0.username ?? $0.contactName)?.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
    }
}
