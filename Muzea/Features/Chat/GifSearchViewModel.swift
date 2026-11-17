import Foundation

/// Состояние поиска GIF: первая страница, запрос, загрузка. Ошибки сети не
/// показываем — репозиторий отдаёт кэш или пустой список.
@MainActor
final class GifSearchViewModel: ObservableObject {
    @Published private(set) var gifs: [Gif] = []
    @Published private(set) var isLoading = false
    @Published var query = ""

    private let repository: GifRepository
    private var loaded = false

    init(repository: GifRepository) {
        self.repository = repository
    }

    func loadIfNeeded() async {
        guard !loaded else { return }
        loaded = true
        await search(query: "")
    }

    func search(query: String) async {
        isLoading = true
        gifs = await repository.search(query: query, page: 0, size: 24)
        isLoading = false
    }
}
