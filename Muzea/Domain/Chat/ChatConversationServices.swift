import Foundation

/// Зависимости экрана переписки, собранные в DI-контейнере. Набор намеренно
/// узкий: диалоги нужны для пересылки и подсказок упоминаний, остальное — для
/// сообщений и их действий.
struct ChatConversationServices {
    let messages: MessageRepository
    let actions: MessageActionsRepository
    let reactions: MessageReactionRepository
    let receipts: MessageReceiptRepository
    let drafts: ChatDraftStore
    let chats: ChatRepository
}
