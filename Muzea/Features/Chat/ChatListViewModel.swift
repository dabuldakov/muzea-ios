import Foundation

@MainActor
final class ChatListViewModel: ObservableObject {
    @Published private(set) var state: ChatListUiState

    private let repository: ChatRepository
    private var isLoading = false

    init(repository: ChatRepository) {
        self.repository = repository
        // Стартуем с кэша, чтобы список был виден до первой сетевой загрузки.
        let cached = repository.cachedChats()
        state = ChatListUiState(chats: cached, isLoading: cached.isEmpty)
    }

    /// Экран дёргает загрузку из `.task` и из автообновления раз в 8 секунд.
    /// Флаг не даёт запросам накладываться друг на друга.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        if state.chats.isEmpty { state.isLoading = true }

        do {
            let chats = try await repository.loadChats()
            state = ChatListUiState(chats: chats, isLoading: false, error: nil)
        } catch {
            state.isLoading = false
            // Список из кэша ценнее сообщения об ошибке: не даём ошибке занять
            // место данных, но и молча не проглатываем.
            state.error = state.chats.isEmpty ? error.localizedDescription : "Error: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func startAutoRefresh() async {
        while !Task.isCancelled {
            await load()
            try? await Task.sleep(nanoseconds: Config.chatListRefreshInterval)
        }
    }

    func consumeError() {
        state.error = nil
    }
}
