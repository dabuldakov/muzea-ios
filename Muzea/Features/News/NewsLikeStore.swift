import Combine
import Foundation

struct NewsLikeState: Equatable {
    var likedByMe: Bool
    var likes: Int64
}

/// Единое состояние лайков новостей для ленты и детального экрана.
///
/// Оба экрана живут в разных ViewModel. Без общего store лайк в ленте не
/// виден в новости и наоборот. Store хранит только изменённые пользователем
/// лайки и накладывает их поверх данных сервера, поэтому не нужен полный
/// refetch ленты после возврата из новости.
@MainActor
final class NewsLikeStore: ObservableObject {
    @Published private(set) var states: [Int64: NewsLikeState] = [:]

    private let repository: NewsRepository
    private var inFlight: Set<Int64> = []

    init(repository: NewsRepository) {
        self.repository = repository
    }

    func apply(_ news: News) -> News {
        guard let state = states[news.id] else { return news }
        guard state.likedByMe != news.likedByMe || state.likes != news.likes else {
            return news
        }
        var updated = news
        updated.likedByMe = state.likedByMe
        updated.likes = state.likes
        return updated
    }

    /// Оптимистично переключает лайк. Возвращает текст ошибки или nil.
    func toggle(_ news: News) async -> String? {
        guard !inFlight.contains(news.id) else { return nil }
        inFlight.insert(news.id)
        defer { inFlight.remove(news.id) }

        let previous = states[news.id] ?? NewsLikeState(
            likedByMe: news.likedByMe,
            likes: news.likes
        )
        let target = !previous.likedByMe
        let optimistic = NewsLikeState(
            likedByMe: target,
            likes: max(0, previous.likes + (target ? 1 : -1))
        )
        publish(news.id, optimistic)

        do {
            let likes = target
                ? try await repository.likeNews(news.id)
                : try await repository.unlikeNews(news.id)
            publish(news.id, NewsLikeState(likedByMe: target, likes: max(0, likes)))
            return nil
        } catch {
            publish(news.id, previous)
            return error.localizedDescription
        }
    }

    /// Меняем словарь целиком: так @Published гарантированно уведомляет
    /// подписчиков даже при изменении одного элемента.
    private func publish(_ id: Int64, _ state: NewsLikeState) {
        var next = states
        next[id] = state
        states = next
    }
}
