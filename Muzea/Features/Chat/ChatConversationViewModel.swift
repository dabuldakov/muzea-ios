import Foundation

@MainActor
final class ChatConversationViewModel: ObservableObject {
    @Published var messages: [MessageResponse] = []
    @Published var error: String?

    let chatUuid: String
    let myUserUuid: String?

    private let repository: ChatRepository
    private var lastMarkedRead: String?

    init(chatUuid: String, repository: ChatRepository, myUserUuid: String?) {
        self.chatUuid = chatUuid
        self.repository = repository
        self.myUserUuid = myUserUuid
    }

    func start() async {
        await refresh()
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: Config.chatPollInterval)
            await refresh()
        }
    }

    func refresh() async {
        do {
            let loaded = try await repository.loadMessages(chatUuid: chatUuid)
            merge(loaded)
            await markRead()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
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
            messages.removeAll { $0.messageUuid == optimistic.messageUuid }
            merge([sent])
            await markRead()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func merge(_ incoming: [MessageResponse]) {
        var map: [String: MessageResponse] = [:]
        for message in incoming { map[message.messageUuid] = message }
        for message in messages { map[message.messageUuid] = message }
        messages = map.values.sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
    }

    private func markRead() async {
        guard let latest = messages.last(where: { !$0.messageUuid.hasPrefix("local-") }) else { return }
        guard latest.messageUuid != lastMarkedRead else { return }
        lastMarkedRead = latest.messageUuid
        await repository.markMessagesAsRead(chatUuid: chatUuid, upToMessageUuid: latest.messageUuid)
    }
}
