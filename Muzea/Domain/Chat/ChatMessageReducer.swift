import Foundation

/// Чистая логика формирования списка сообщений переписки: сортировка по времени,
/// слияние с серверным списком и подмена локального пузыря серверным эхом без
/// смены идентификатора.
///
/// Если удалить локальный пузырь и вставить серверное сообщение заново, список
/// (аналог DiffUtil на Android) посчитает строку другой и перерисует её — при
/// отправке список мигает. Здесь идентификатор сохраняется, поэтому это обычное
/// изменение содержимого. Вынесено из ViewModel, чтобы покрывать сценарии без
/// UIKit и без сети.
final class ChatMessageReducer {

    /// serverUuid -> localUuid для отправленных нами сообщений.
    private var serverToLocal: [String: String] = [:]

    /// Стартовый список из кэша: сервер отдаёт «сначала новые», показываем по возрастанию.
    func seed(_ cached: [MessageResponse]) -> [MessageResponse] {
        cached.sorted(by: Self.areInIncreasingOrder)
    }

    /// Сливает серверную пачку с текущим списком. Существующие элементы имеют
    /// приоритет, а серверное эхо уже отправленных нами сообщений пропускается —
    /// оно показано локальным пузырём.
    func merge(current: [MessageResponse], incoming: [MessageResponse]) -> [MessageResponse] {
        var merged: [String: MessageResponse] = [:]
        for message in incoming where serverToLocal[message.messageUuid] == nil {
            merged[message.messageUuid] = message
        }
        for message in current {
            merged[message.messageUuid] = message
        }
        return merged.values.sorted(by: Self.areInIncreasingOrder)
    }

    /// Обновляет локальный пузырь данными серверного эха, сохраняя его uuid,
    /// и запоминает соответствие серверного uuid локальному.
    func applyServerEcho(
        current: [MessageResponse],
        localUuid: String,
        serverMessage: MessageResponse
    ) -> [MessageResponse] {
        serverToLocal[serverMessage.messageUuid] = localUuid
        return current
            .map { existing in
                existing.messageUuid == localUuid ? serverMessage.withMessageUuid(localUuid) : existing
            }
            .sorted(by: Self.areInIncreasingOrder)
    }

    /// Порядок по `createdAt` по возрастанию. Сообщения без времени («пузырь»
    /// до ответа сервера) уходят в конец, как и на Android.
    static func areInIncreasingOrder(_ a: MessageResponse, _ b: MessageResponse) -> Bool {
        let ta = a.createdAt ?? ""
        let tb = b.createdAt ?? ""
        if ta.isEmpty { return false }
        if tb.isEmpty { return true }
        return ta < tb
    }
}
