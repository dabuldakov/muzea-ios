import Foundation

@MainActor
final class ChatListViewModel: ObservableObject {
    @Published var chats: [ChatResponse] = []
    @Published var isLoading = false
    @Published var error: String?

    private let repository: ChatRepository

    init(repository: ChatRepository) {
        self.repository = repository
    }

    func load() async {
        do {
            chats = try await repository.loadChats()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startAutoRefresh() async {
        while !Task.isCancelled {
            await load()
            try? await Task.sleep(nanoseconds: 8_000_000_000)
        }
    }
}
