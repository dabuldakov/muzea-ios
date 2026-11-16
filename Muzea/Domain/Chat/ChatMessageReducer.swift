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
    /// localUuid -> serverUuid: действия уходят на сервер с реальным id.
    private var localToServer: [String: String] = [:]

    /// Реальный серверный uuid для локального (или тот же, если уже серверный).
    func serverUuid(_ localOrServer: String) -> String {
        localToServer[localOrServer] ?? localOrServer
    }

    /// Локальный uuid для серверного (если это наше отправленное сообщение).
    func localUuidFor(_ serverUuid: String) -> String? {
        serverToLocal[serverUuid]
    }

    /// Версия для кэша: локальные uuid не должны «всплывать» после перезахода.
    func toServerIdentities(_ messages: [MessageResponse]) -> [MessageResponse] {
        messages.map { message in
            message.replacing(
                messageUuid: serverUuid(message.messageUuid),
                replyToMessageUuid: message.replyToMessageUuid.map(serverUuid)
            )
        }
    }

    /// Стартовый список из кэша: сервер отдаёт «сначала новые», показываем по
    /// возрастанию. Удалённые сообщения не показываем вовсе.
    func seed(_ cached: [MessageResponse]) -> [MessageResponse] {
        cached
            .filter { $0.isDeleted != true }
            .sorted(by: Self.areInIncreasingOrder)
    }

    /// Сливает серверную пачку с текущим списком. Входящие серверные данные
    /// важнее локальной копии (приходят правки и снятые реакции), серверное эхо
    /// наших отправок пропускается — оно показано локальным пузырём.
    func merge(current: [MessageResponse], incoming: [MessageResponse]) -> [MessageResponse] {
        var merged: [String: MessageResponse] = [:]
        let deleted = Set(incoming.filter { $0.isDeleted == true }.map { $0.messageUuid })

        for message in incoming {
            if message.isDeleted == true { continue }
            if serverToLocal[message.messageUuid] != nil { continue }
            merged[message.messageUuid] = message
        }
        for message in current {
            if message.isDeleted == true || deleted.contains(message.messageUuid) { continue }
            if merged[message.messageUuid] == nil {
                merged[message.messageUuid] = message
            }
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
        localToServer[localUuid] = serverMessage.messageUuid
        return current
            .map { existing in
                guard existing.messageUuid == localUuid else { return existing }
                let reply = serverMessage.replyToMessageUuid
                    .map { serverToLocal[$0] ?? $0 }
                    ?? existing.replyToMessageUuid
                var echoed = serverMessage
                    .withMessageUuid(localUuid)
                    .replacing(replyToMessageUuid: reply)
                // Сервер может не вернуть power — не теряем заряд, накопленный
                // при удержании кнопки.
                if (echoed.power ?? 0) == 0, let localPower = existing.power, localPower > 0 {
                    echoed = echoed.replacing(power: localPower)
                }
                return echoed
            }
            .sorted(by: Self.areInIncreasingOrder)
    }

    /// Заменяет сообщение с тем же uuid (правка/закреп/реакции), не меняя порядок.
    func updateMessage(current: [MessageResponse], updated: MessageResponse) -> [MessageResponse] {
        current.map { $0.messageUuid == updated.messageUuid ? updated : $0 }
    }

    /// Убирает сообщение локально (после мягкого удаления).
    func removeMessage(current: [MessageResponse], messageUuid: String) -> [MessageResponse] {
        current.filter { $0.messageUuid != messageUuid }
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
