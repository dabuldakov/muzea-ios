import Foundation

/// Что показывать на экране списка чатов.
enum ChatListViewState: Equatable {
    /// Есть что показать: список.
    case list
    /// Показать нечего, показать заглушку «чатов нет».
    case empty
    /// Показать нечего, показать текст ошибки.
    case error
    /// Показать нечего и данные ещё идут: показать индикатор.
    case loading
}

/// Единое состояние списка чатов (список + загрузка + ошибка).
///
/// `viewState` считается от переданного списка, а не от состояния UI-компонента:
/// иначе первый же пустой ответ сервера залипал бы в «пусто» навсегда.
struct ChatListUiState: Equatable {
    var chats: [ChatResponse] = []
    var isLoading = false
    var error: String?

    var viewState: ChatListViewState {
        if !chats.isEmpty { return .list }
        if isLoading { return .loading }
        if error != nil { return .error }
        return .empty
    }
}
