import Foundation

/// Какой чат сейчас открыт: пуш по нему не показываем и снимаем из шторки.
final class ActiveChatTracker {
    static let shared = ActiveChatTracker()
    private let lock = NSLock()
    private var current: String?

    var chatUuid: String? {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func enter(_ chatUuid: String) {
        lock.lock()
        current = chatUuid
        lock.unlock()
    }

    func leave(_ chatUuid: String) {
        lock.lock()
        if current == chatUuid { current = nil }
        lock.unlock()
    }
}
