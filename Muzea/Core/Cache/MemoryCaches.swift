import Foundation

/// Потокобезопасный словарь с ограничением размера и порядком вставки — аналог
/// `@Synchronized LinkedHashMap` из Android-кэшей. При переполнении вытесняется
/// самая старая запись.
final class LRUStore<Key: Hashable, Value> {
    private let limit: Int
    private var order: [Key] = []
    private var storage: [Key: Value] = [:]
    private let lock = NSLock()

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    func value(for key: Key) -> Value? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]
    }

    func contains(_ key: Key) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return storage[key] != nil
    }

    func set(_ value: Value, for key: Key) {
        lock.lock(); defer { lock.unlock() }
        if storage[key] != nil, let index = order.firstIndex(of: key) {
            order.remove(at: index)
        }
        storage[key] = value
        order.append(key)
        evictIfNeeded()
    }

    /// Полная замена содержимого с сохранением порядка переданных значений.
    /// Повторный ключ обновляет значение, но не двигает запись — как
    /// `LinkedHashMap` на Android.
    func replace(_ entries: [(Key, Value)]) {
        lock.lock(); defer { lock.unlock() }
        order.removeAll()
        storage.removeAll()
        for (key, value) in entries {
            if storage[key] == nil {
                order.append(key)
            }
            storage[key] = value
        }
        evictIfNeeded()
    }

    func all() -> [Value] {
        lock.lock(); defer { lock.unlock() }
        return order.compactMap { storage[$0] }
    }

    func isEmpty() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return storage.isEmpty
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        order.removeAll()
        storage.removeAll()
    }

    private func evictIfNeeded() {
        while order.count > limit {
            let oldest = order.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }
}

/// Кэш списка чатов в памяти процесса. Репозиторий и ViewModel создаются заново
/// при каждом показе экрана, поэтому общий кэш отдаёт список мгновенно, пока
/// актуальные данные догружаются сетью (аналог Android `ChatListCache`).
final class ChatListCache {
    private let store = LRUStore<String, Chat>(limit: 200)

    func get() -> [Chat] { store.all() }
    func has() -> Bool { !store.isEmpty() }
    func put(_ list: [Chat]) {
        store.replace(list.filter { !$0.chatUuid.isEmpty }.map { ($0.chatUuid, $0) })
    }
    func clear() { store.clear() }
}

/// Кэш сообщений по чатам. Позволяет мгновенно показать переписку при повторном
/// входе, пока свежие сообщения догружаются в фоне (аналог `ChatMessagesCache`).
final class ChatMessagesCache {
    private let store = LRUStore<String, [ChatMessage]>(limit: 50)

    func get(chatUuid: String) -> [ChatMessage] { store.value(for: chatUuid) ?? [] }
    func has(chatUuid: String) -> Bool { store.contains(chatUuid) }
    func put(chatUuid: String, list: [ChatMessage]) { store.set(list, for: chatUuid) }

    /// Догрузка истории вверх: старые сообщения добавляются перед текущими
    /// без дублей, кэш остаётся в порядке возрастания времени.
    func prepend(chatUuid: String, older: [ChatMessage]) {
        guard !older.isEmpty else { return }
        let current = store.value(for: chatUuid) ?? []
        let known = Set(current.map(\.messageUuid))
        let fresh = older.filter { !known.contains($0.messageUuid) }
        guard !fresh.isEmpty else { return }
        store.set((fresh + current).sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }, for: chatUuid)
    }

    /// Новые сообщения из инкрементального опроса: заменяем известные по uuid
    /// и сохраняем порядок по времени (аналог `appendNewer` на Android).
    func appendNewer(chatUuid: String, newer: [ChatMessage]) {
        guard !newer.isEmpty else { return }
        let current = store.value(for: chatUuid) ?? []
        var byUuid: [String: ChatMessage] = [:]
        for message in current {
            byUuid[message.messageUuid] = message
        }
        for message in newer {
            byUuid[message.messageUuid] = message
        }
        store.set(
            byUuid.values.sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") },
            for: chatUuid
        )
    }
    func clear() { store.clear() }
}

/// Кэш соответствия «пользователь → уже существующий приватный чат».
///
/// Поиск переписки требует обхода приватных чатов и запроса их участников, что
/// при каждом тапе по контакту дорого. Состав участников приватного чата со
/// временем не меняется, поэтому найденную пару запоминаем на сессию
/// (аналог `PrivateChatCache`).
final class PrivateChatCache {
    private let store = LRUStore<String, Chat>(limit: 200)

    func get(userUuid: String) -> Chat? { store.value(for: userUuid) }
    func put(userUuid: String, chat: Chat) {
        guard !userUuid.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        store.set(chat, for: userUuid)
    }
    func clear() { store.clear() }
}

/// Кэш списка видео в памяти процесса (аналог `VideoListCache`).
final class VideoListCache {
    private let store = LRUStore<Int64, Video>(limit: 200)

    func get() -> [Video] { store.all() }
    func has() -> Bool { !store.isEmpty() }
    func put(_ list: [Video]) {
        store.replace(list.map { ($0.id, $0) })
    }
    func clear() { store.clear() }
}
