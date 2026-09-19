import Foundation

@MainActor
final class NewsListViewModel: ObservableObject {
    @Published var news: [NewsResponse] = []
    @Published var isLoading = false
    @Published var error: String?

    private let newsRepository: NewsRepository
    private let chatRepository: ChatRepository
    private let ownUsername: String?
    private let pageSize = Config.newsPageSize

    private var raw: [NewsResponse] = []
    private var contactUsernames: Set<String> = []
    private var contactsLoaded = false
    private var page = 0
    private var endReached = false

    init(newsRepository: NewsRepository, chatRepository: ChatRepository, ownUsername: String?) {
        self.newsRepository = newsRepository
        self.chatRepository = chatRepository
        self.ownUsername = ownUsername
    }

    func load(reset: Bool = true) async {
        guard !isLoading else { return }
        isLoading = true
        if reset {
            raw = []
            news = []
            page = 0
            endReached = false
        }

        do {
            if !contactsLoaded {
                contactsLoaded = true
                if let contacts = try? await chatRepository.loadContacts() {
                    contactUsernames = Set(
                        contacts
                            .compactMap { ($0.username ?? $0.contactName)?.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                    )
                }
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
                news = NewsFeedFilter.filter(raw, contactUsernames: contactUsernames, ownUsername: ownUsername)
                iterations += 1
            } while !endReached && news.count < pageSize && iterations < 10

            error = nil
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreIfNeeded(currentItem: NewsResponse) async {
        guard !endReached, !isLoading else { return }
        guard let index = news.firstIndex(of: currentItem), index >= news.count - 2 else { return }
        await load(reset: false)
    }

    func delete(_ item: NewsResponse) async -> Bool {
        do {
            try await newsRepository.deleteNews(item.id)
            raw.removeAll { $0.id == item.id }
            news.removeAll { $0.id == item.id }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
