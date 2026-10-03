import Foundation

/// Единое состояние экрана переписки.
struct ChatConversationUiState: Equatable {
    var messages: [MessageResponse] = []
    var isLoading = false
    var error: String?
}

@MainActor
final class ChatConversationViewModel: ObservableObject {
    @Published private(set) var state = ChatConversationUiState()

    let chatUuid: String
    let myUserUuid: String?

    private let repository: MessageRepository
    private let reducer = ChatMessageReducer()
    private var lastMarkedReadUuid: String?

    init(chatUuid: String, repository: MessageRepository, myUserUuid: String?) {
        self.chatUuid = chatUuid
        self.repository = repository
        self.myUserUuid = myUserUuid
        // Стартуем с кэша: при повторном входе переписка видна сразу, а опрос
        // догружает свежие сообщения фоном. Кэш хранит сообщения в порядке
        // сервера (сначала новые), поэтому seed() сортирует их до показа.
        state.messages = reducer.seed(repository.cachedMessages(chatUuid: chatUuid))
    }

    /// Опрос: первый запрос уходит сразу, поэтому отдельный refresh() при входе
    /// был бы вторым обращением к серверу подряд.
    func start() async {
        while !Task.isCancelled {
            await loadOnce()
            try? await Task.sleep(nanoseconds: Config.chatPollInterval)
        }
    }

    /// Разовая загрузка вне цикла опроса (pull-to-refresh).
    func refresh() async {
        await loadOnce()
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let optimistic = MessageResponse(
            messageUuid: "local-\(Int(Date().timeIntervalSince1970 * 1000))",
            chatUuid: chatUuid,
            senderId: nil,
            senderUuid: myUserUuid,
            senderName: nil,
            senderAvatar: nil,
            text: trimmed,
            messageType: "TEXT",
            replyToMessageUuid: nil,
            isEdited: false,
            isDeleted: false,
            isPinned: false,
            createdAt: nil,
            updatedAt: nil
        )
        merge([optimistic])

        do {
            let sent = try await repository.sendMessage(chatUuid: chatUuid, text: trimmed)
            state.messages = reducer.applyServerEcho(
                current: state.messages,
                localUuid: optimistic.messageUuid,
                serverMessage: sent
            )
            await markRead()
        } catch {
            state.error = error.localizedDescription
        }
    }

    private func loadOnce() async {
        // Спиннер показываем только когда показать нечего: переписка из кэша уже
        // на экране, и мигать индикатором при входе незачем.
        if state.messages.isEmpty { state.isLoading = true }
        do {
            let loaded = try await repository.loadMessages(chatUuid: chatUuid)
            state.isLoading = false
            state.error = nil
            merge(loaded)
            await markRead()
        } catch {
            state.isLoading = false
            state.error = error.localizedDescription
        }
    }

    private func merge(_ incoming: [MessageResponse]) {
        state.messages = reducer.merge(current: state.messages, incoming: incoming)
    }

    private func markRead() async {
        let latest = state.messages.last {
            !$0.messageUuid.isEmpty && !$0.messageUuid.hasPrefix("local-")
        }
        guard let latest, latest.messageUuid != lastMarkedReadUuid else { return }
        lastMarkedReadUuid = latest.messageUuid
        await repository.markMessagesAsRead(chatUuid: chatUuid, upToMessageUuid: latest.messageUuid)
    }
}
