import Foundation

enum GifTab: CaseIterable, Identifiable {
    case recent
    case chat
    case search

    var id: String {
        switch self {
        case .recent: return "recent"
        case .chat: return "chat"
        case .search: return "search"
        }
    }

    var title: String {
        switch self {
        case .recent: return "Мои"
        case .chat: return "Этот чат"
        case .search: return "Поиск"
        }
    }
}

/// Состояние пикера GIF: «Мои», «Этот чат», поиск Klipy, постраничная догрузка.
@MainActor
final class GifSearchViewModel: ObservableObject {
    static let pageSize = 30

    @Published private(set) var gifs: [Gif] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasMore = true
    @Published var tab: GifTab = .recent
    @Published var query = ""

    private let repository: GifRepository
    private let chatUuid: String
    private var nextPage = 0
    private var loadedOnce = false

    init(repository: GifRepository, chatUuid: String = "") {
        self.repository = repository
        self.chatUuid = chatUuid
    }

    func loadIfNeeded() async {
        guard !loadedOnce else { return }
        loadedOnce = true
        await reload()
    }

    func select(_ tab: GifTab) async {
        guard self.tab != tab else { return }
        self.tab = tab
        await reload()
    }

    func search(query: String) async {
        self.query = query
        guard tab == .search else { return }
        await reload()
    }

    func reload() async {
        nextPage = 0
        hasMore = true
        gifs = []
        await loadNextPage()
    }

    func loadNextPage() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }

        let page = nextPage
        let items: [Gif]
        switch tab {
        case .recent:
            items = await repository.recent(page: page, size: Self.pageSize)
        case .chat:
            guard !chatUuid.isEmpty else {
                hasMore = false
                return
            }
            items = await repository.chat(
                chatUuid: chatUuid,
                page: page,
                size: Self.pageSize
            )
        case .search:
            items = await repository.search(
                query: query,
                page: page,
                size: Self.pageSize
            )
        }

        gifs.append(contentsOf: items)
        nextPage = page + 1
        hasMore = items.count >= Self.pageSize
    }
}
