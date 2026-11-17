import Foundation

/// Все строки интерфейса идут через этот слой: в вью нет русских литералов.
/// Таблицы лежат в `Resources/ru.lproj` и `Resources/en.lproj`.
/// `scripts/check_localization.py` проверяет, что каждый ключ есть в обеих
/// таблицах, поэтому опечатка в имени не проходит молча.
enum L10n {

    // MARK: - Common

    static var close: String { t("common.close") }
    static var cancel: String { t("common.cancel") }
    static var delete: String { t("common.delete") }
    static var done: String { t("common.done") }
    static var add: String { t("common.add") }
    static var create: String { t("common.create") }
    static var error: String { t("common.error") }
    static var share: String { t("common.share") }
    static var retry: String { t("common.retry") }
    static var copy: String { t("common.copy") }
    static var select: String { t("common.select") }
    static var edit: String { t("common.edit") }

    // MARK: - Chat

    static var chat: String { t("chat.title") }
    static var chatList: String { t("chat.list.title") }
    static var chatListEmpty: String { t("chat.list.empty") }
    static var messagesEmpty: String { t("chat.messages.empty") }
    static var deletedUser: String { t("chat.deletedUser") }
    static var participant: String { t("chat.participant") }
    static var you: String { t("chat.you") }
    static var unknownUser: String { t("chat.unknownUser") }
    static var userDeletedBanner: String { t("chat.userDeleted") }
    static var aboutChat: String { t("chat.about") }
    static var forwarded: String { t("chat.forwarded") }
    static var editedShort: String { t("chat.editedShort") }
    static var messagePlaceholder: String { t("chat.placeholder") }
    static var newTextPlaceholder: String { t("chat.newTextPlaceholder") }
    static var editing: String { t("chat.editing") }
    static var reply: String { t("chat.reply") }
    static var forward: String { t("chat.forward") }
    static var pin: String { t("chat.pin") }
    static var unpin: String { t("chat.unpin") }
    static var pinnedOne: String { t("chat.pinnedOne") }
    static var details: String { t("chat.details") }
    static var report: String { t("chat.report") }
    static var block: String { t("chat.block") }
    static var reaction: String { t("chat.reaction") }
    static var recentReactions: String { t("chat.reactions.recent") }
    static var allReactions: String { t("chat.reactions.all") }
    static var exitSelection: String { t("chat.selection.exit") }
    static var forwardSelected: String { t("chat.selection.forward") }
    static var deleteSelected: String { t("chat.selection.delete") }
    static var attachment: String { t("chat.attachment") }
    static var photo: String { t("chat.photo") }
    static var video: String { t("chat.video") }
    static var videoNote: String { t("chat.videoNote") }
    static var file: String { t("chat.file") }
    static var emojiGif: String { t("chat.emojiGif") }
    static var emoji: String { t("chat.emoji") }
    static var gif: String { t("chat.gif") }
    static var mode: String { t("chat.mode") }
    static var attach: String { t("chat.attach") }
    static var removeAttachment: String { t("chat.removeAttachment") }
    static var cancelReply: String { t("chat.cancelReply") }
    static var cancelEditing: String { t("chat.cancelEditing") }
    static var recording: String { t("chat.recording") }
    static var recordVoice: String { t("chat.recordVoice") }
    static var recordVoiceHint: String { t("chat.recordVoice.hint") }
    static var voiceFallback: String { t("chat.voiceFallback") }
    static var playVoice: String { t("chat.playVoice") }
    static var pause: String { t("chat.pause") }
    static var audioFallback: String { t("chat.audioFallback") }
    static var videoFallback: String { t("chat.videoFallback") }
    static var attachmentFallback: String { t("chat.attachmentFallback") }
    static var fileFallback: String { t("chat.fileFallback") }
    static var saveToPhotos: String { t("chat.saveToPhotos") }
    static var saveFailed: String { t("chat.saveFailed") }
    static var forwardTitle: String { t("chat.forwardTitle") }
    static var forwardCommentPlaceholder: String { t("chat.forward.comment") }
    static var forwardWhere: String { t("chat.forward.where") }
    static var forwardNoChats: String { t("chat.forward.none") }
    static var sendToChat: String { t("chat.sendToChat") }
    static var messageDetails: String { t("chat.details.title") }
    static var deliveryStatus: String { t("chat.deliveryStatus") }
    static var reactionsSection: String { t("chat.reactions.section") }
    static var noData: String { t("chat.noData") }
    static var reacted: String { t("chat.reacted") }
    static var statusRead: String { t("chat.status.read") }
    static var statusDelivered: String { t("chat.status.delivered") }
    static var statusSent: String { t("chat.status.sent") }
    static var statusSending: String { t("chat.status.sending") }
    static var statusFailed: String { t("chat.status.failed") }
    static var deleteMessageTitle: String { t("chat.delete.title") }
    static var deleteMessageBody: String { t("chat.delete.body") }
    static var deleteSelectedTitle: String { t("chat.deleteSelected.title") }
    static var deleteSelectedBody: String { t("chat.deleteSelected.body") }
    static var blockTitle: String { t("chat.block.title") }
    static var blockBody: String { t("chat.block.body") }
    static var gifsEmpty: String { t("chat.gifs.empty") }
    static var gifsLoadMore: String { t("chat.gifs.more") }
    static var gifsSearchPlaceholder: String { t("chat.gifs.search") }
    static var gifsUnavailable: String { t("chat.gifs.unavailable") }
    static var gifsRecent: String { t("chat.gifs.recent") }
    static var gifsChat: String { t("chat.gifs.chat") }
    static var gifsSearchTab: String { t("chat.gifs.searchTab") }
    static var reportTitle: String { t("chat.report.title") }
    static var reportSpam: String { t("chat.report.spam") }
    static var reportAbuse: String { t("chat.report.abuse") }
    static var reportViolence: String { t("chat.report.violence") }
    static var reportAdult: String { t("chat.report.adult") }
    static var reportIllegal: String { t("chat.report.illegal") }
    static var reportOther: String { t("chat.report.other") }
    static var chatGroupNew: String { t("chat.group.new") }
    static var chatGroupName: String { t("chat.group.name") }
    static var chatGroupNamePlaceholder: String { t("chat.group.namePlaceholder") }
    static var chatGroupMembers: String { t("chat.group.members") }
    static var chatGroupChooseMembers: String { t("chat.group.chooseMembers") }
    static var chatGroupNoMembers: String { t("chat.group.noMembers") }
    static var chatGroupNoContacts: String { t("chat.group.noContacts") }
    static var chatGroupAddMembers: String { t("chat.group.addMembers") }
    static var chatGroupChangeAvatar: String { t("chat.group.changeAvatar") }
    static var chatGroupAvatarTooLarge: String { t("chat.group.avatarTooLarge") }
    static var videoNoteHint: String { t("chat.videoNote.hint") }

    // MARK: - Ошибки и уведомления чата

    static var errorAttachmentUpload: String { t("chat.error.attachmentUpload") }
    static var errorOnlyOwnDelete: String { t("chat.error.onlyOwnDelete") }
    static var errorEmptyMessage: String { t("chat.error.emptyMessage") }
    static var errorImageRead: String { t("chat.error.imageRead") }
    static var errorImageUnsupported: String { t("chat.error.imageUnsupported") }
    static var errorVideoRead: String { t("chat.error.videoRead") }
    static var errorFileRead: String { t("chat.error.fileRead") }
    static var errorMicrophone: String { t("chat.error.microphone") }
    static var errorRecordStart: String { t("chat.error.recordStart") }
    static var noticeReported: String { t("chat.notice.reported") }
    static var noticeBlocked: String { t("chat.notice.blocked") }

    /// «Ответ: Имя» в баннере композера.
    static func replyBanner(_ name: String) -> String {
        format("chat.replyBanner", name)
    }

    /// «Закреплённые: 3».
    static func pinnedMany(_ count: Int) -> String {
        format("chat.pinnedMany", count)
    }

    /// «Выбрано: 3».
    static func selectedCount(_ count: Int) -> String {
        format("chat.selectedCount", count)
    }

    /// «Можно прикрепить не больше 10 файлов».
    static func attachmentLimit(_ count: Int) -> String {
        format("chat.error.attachmentLimit", count)
    }

    /// «Участники (3)».
    static func groupMembers(_ count: Int) -> String {
        format("chat.group.members.count", count)
    }

    /// Озвучка кнопки реакции для VoiceOver.
    static func reactionAccessibility(_ emoji: String, _ count: Int) -> String {
        format("chat.reaction.accessibility", emoji, count)
    }

    // MARK: - Private

    private static func t(_ key: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: key, comment: "")
    }

    private static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), locale: Locale.current, arguments: args)
    }
}
