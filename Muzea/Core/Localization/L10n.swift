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
    static var uploadFailed: String { t("common.uploadFailed") }
    static var share: String { t("common.share") }
    static var retry: String { t("common.retry") }
    static var copy: String { t("common.copy") }
    static var select: String { t("common.select") }
    static var edit: String { t("common.edit") }
    static var save: String { t("common.save") }
    static var reportAlert: String { t("common.report") }
    static var reported: String { t("common.reported") }

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
    static var groupRoleOwner: String { t("chat.group.role.owner") }
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

    // MARK: - Auth

    static var registerTitle: String { t("auth.register.title") }
    static var confirmTitle: String { t("auth.confirm.title") }
    static var authAccount: String { t("auth.account") }
    static var usernameField: String { t("auth.username") }
    static var displayNameField: String { t("auth.displayName") }
    static var consentToggle: String { t("auth.consent.toggle") }
    static var termsLink: String { t("auth.terms") }
    static var policyLink: String { t("auth.policy") }
    static var registerAction: String { t("auth.register.action") }
    static var confirmEmailSection: String { t("auth.confirm.section") }
    static var codeField: String { t("auth.code") }
    static var codeTitle: String { t("auth.code.title") }
    static var confirmAction: String { t("auth.confirm.action") }
    static var resendCode: String { t("auth.resend") }
    static func resendIn(_ seconds: Int) -> String { format("auth.resendIn", seconds) }
    static var changeData: String { t("auth.changeData") }
    static var emailInvalid: String { t("auth.error.email") }
    static var codeRequired: String { t("auth.error.code") }
    static var codeTooShort: String { t("auth.error.codeTooShort") }
    static var usernameInvalid: String { t("auth.error.username") }
    static var consentTitle: String { t("auth.consent.title") }
    static var consentOpenTerms: String { t("auth.consent.terms") }
    static var consentOpenPolicy: String { t("auth.consent.policy") }
    static var consentAccept: String { t("auth.consent.accept") }
    static var consentDecline: String { t("auth.consent.decline") }
    static var getCode: String { t("auth.getCode") }
    static var signIn: String { t("auth.signIn") }
    static var changeEmail: String { t("auth.changeEmail") }
    static var legalNote: String { t("auth.legalNote") }
    static var reauthTitle: String { t("auth.reauth.title") }
    static var reauthBody: String { t("auth.reauth.body") }
    static var reauthRegister: String { t("auth.reauth.register") }
    static var reauthOk: String { t("auth.reauth.ok") }
    static var emailNotRegistered: String { t("auth.error.notRegistered") }
    static var accountDeactivated: String { t("auth.error.accountDeleted") }

    static func codeSent(_ email: String) -> String {
        format("auth.code.sent", email)
    }

    static func codeSentAgain(_ email: String) -> String {
        format("auth.code.sentAgain", email)
    }

    static func verificationSent(_ email: String) -> String {
        format("auth.verificationSent", email)
    }

    // MARK: - Contacts

    static var contactsTitle: String { t("contact.title") }
    static var addContact: String { t("contact.add") }
    static var contactsEmpty: String { t("contact.empty") }
    static var contactFallbackName: String { t("contact.fallbackName") }
    static var contactNoUuid: String { t("contact.error.noUuid") }

    // MARK: - News

    static var newsTitle: String { t("news.title") }
    static var newsEmpty: String { t("news.empty") }
    static var newsDetail: String { t("news.detail") }
    static var newsDelete: String { t("news.delete") }
    static var newsDeleteTitle: String { t("news.delete.title") }
    static var newsCreate: String { t("news.create") }
    static var newsSection: String { t("news.section") }
    static var newsHeadingField: String { t("news.heading") }
    static var newsTextField: String { t("news.text") }
    static var newsImageSection: String { t("news.image") }
    static var newsPickImage: String { t("news.pickImage") }
    static var newsImageChosen: String { t("news.imageChosen") }
    static var newsVideoSection: String { t("news.video") }
    static var newsNone: String { t("news.none") }
    static var newsPublish: String { t("news.publish") }
    static var newsEditTitle: String { t("news.edit.title") }
    static var newsRemoveImage: String { t("news.removeImage") }
    static var newsCommentsTitle: String { t("news.comments.title") }
    static var newsLoadOlder: String { t("news.comments.loadOlder") }
    static var newsCommentsEmpty: String { t("news.comments.empty") }
    static var newsCommentHint: String { t("news.comments.hint") }
    static var newsDeleteCommentTitle: String { t("news.comments.delete.title") }
    static var newsActions: String { t("news.actions") }

    static func newsAuthor(_ name: String) -> String {
        format("news.author", name)
    }

    static func newsWatch(_ title: String) -> String {
        format("news.watch", title)
    }

    // MARK: - Profile

    static var profileTitle: String { t("profile.title") }
    static var languageLabel: String { t("profile.language") }
    static var languageTitle: String { t("profile.language.title") }
    static var languageSystem: String { t("profile.language.system") }
    static var changeAvatar: String { t("profile.changeAvatar") }
    static var deleteAvatar: String { t("profile.deleteAvatar") }
    static var loginLabel: String { t("profile.login") }
    static var fullNameField: String { t("profile.fullName") }
    static var roleLabel: String { t("profile.role") }
    static var operatorLink: String { t("profile.operator") }
    static var cacheLabel: String { t("profile.cache") }
    static var clearCache: String { t("profile.clearCache") }
    static var cacheCleared: String { t("profile.cacheCleared") }
    static var deleteAccount: String { t("profile.deleteAccount") }
    static var signOut: String { t("profile.signOut") }
    static var deleteAccountTitle: String { t("profile.delete.title") }
    static var signOutAction: String { t("profile.signOut.action") }
    static var deactivateDescription: String { t("profile.delete.body") }
    static var avatarTooLarge: String { t("profile.avatarTooLarge") }
    static var chatDeactivateFailed: String { t("profile.error.chat") }
    static var profileLoadFailed: String { t("profile.error.load") }
    static var operatorTitle: String { t("profile.operator.title") }
    static var operatorName: String { t("profile.operator.name") }
    static var operatorStatus: String { t("profile.operator.status") }
    static var operatorINN: String { t("profile.operator.inn") }
    static var operatorAddress: String { t("profile.operator.address") }
    static var operatorContacts: String { t("profile.operator.contacts") }
    static var operatorEmail: String { t("profile.operator.email") }
    static var operatorPhone: String { t("profile.operator.phone") }
    static var operatorDocuments: String { t("profile.operator.documents") }

    // MARK: - Video

    static var videoTitle: String { t("video.title") }
    static var videoEmpty: String { t("video.empty") }
    static var videoDescriptionSection: String { t("video.section") }
    static var videoNameField: String { t("video.name") }
    static var videoDescriptionField: String { t("video.description") }
    static var videoFileSection: String { t("video.file") }
    static var videoPick: String { t("video.pick") }
    static var videoPickFile: String { t("video.pickFile") }
    static var videoChosen: String { t("video.chosen") }
    static var videoCorrupted: String { t("video.corrupted") }
    static var videoUpload: String { t("video.upload") }
    static var videoUploadTitle: String { t("video.upload.title") }
    static var videoDelete: String { t("video.delete") }
    static var videoDeleteTitle: String { t("video.delete.title") }

    static func videoAuthor(_ name: String) -> String {
        format("video.author", name)
    }

    static func videoViews(_ count: Int) -> String {
        format("video.views", count)
    }

    static func videoLikes(_ count: Int) -> String {
        format("video.likes", count)
    }

    // MARK: - Tabs and common shell

    static var tabNews: String { t("app.tab.news") }
    static var tabChats: String { t("app.tab.chats") }
    static var tabContacts: String { t("app.tab.contacts") }
    static var tabVideo: String { t("app.tab.video") }
    static var tabProfile: String { t("app.tab.profile") }
    static var noInternet: String { t("app.noInternet") }

    // MARK: - Errors

    static var sessionExpired: String { t("error.sessionExpired") }
    static var networkUnavailable: String { t("error.network") }
    static var invalidURL: String { t("error.invalidURL") }
    static var unexpectedResponse: String { t("error.unexpected") }
    static var unauthorized: String { t("error.unauthorized") }
    static var emptyResponse: String { t("error.emptyResponse") }
    static var otpInvalid: String { t("auth.error.otpInvalid") }
    static var otpExpired: String { t("auth.error.otpExpired") }
    static var otpNotFound: String { t("auth.error.otpNotFound") }
    static var otpAttempts: String { t("auth.error.otpAttempts") }
    static var cooldown: String { t("auth.error.cooldown") }
    static var rateLimited: String { t("auth.error.rateLimited") }
    static var emailTaken: String { t("auth.error.emailTaken") }
    static var usernameTaken: String { t("auth.error.usernameTaken") }
    static var userNotFound: String { t("auth.error.userNotFound") }
    static var checkInput: String { t("auth.error.checkInput") }

    // MARK: - Domain text

    static var unsupportedFile: String { t("attachment.error.unsupported") }
    static var emptyFile: String { t("attachment.error.empty") }
    static var unknownSender: String { t("preview.unknownSender") }
    static var previewImage: String { t("preview.image") }
    static var previewMessage: String { t("preview.message") }
    static var messageDeleted: String { t("preview.messageDeleted") }
    static var presenceOnline: String { t("presence.online") }
    static var presenceOffline: String { t("presence.offline") }
    static var presenceJustNow: String { t("presence.justNow") }
    static var pushNewMessage: String { t("push.newMessage") }
    static var pushNews: String { t("push.news") }
    static var recorderNoPermission: String { t("recorder.noPermission") }
    static var recorderCameraFailed: String { t("recorder.cameraFailed") }
    static var recorderTooShort: String { t("recorder.tooShort") }
    static var recorderReadFailed: String { t("recorder.readFailed") }

    static func errorDetails(_ details: String) -> String {
        format("error.withDetails", details)
    }

    static func serverError(_ code: Int, _ message: String) -> String {
        format("error.server", code, message)
    }

    static func serverCode(_ code: Int) -> String {
        format("error.serverCode", code)
    }

    static func decodingError(_ description: String) -> String {
        format("error.decoding", description)
    }

    static func transportError(_ description: String) -> String {
        format("error.transport", description)
    }

    static func fileTooLarge(_ megabytes: Int64) -> String {
        format("attachment.error.tooLarge", Int(megabytes))
    }

    static func presenceMinutes(_ minutes: Int) -> String {
        format("presence.minutesAgo", minutes)
    }

    static func presenceHours(_ hours: Int) -> String {
        format("presence.hoursAgo", hours)
    }

    static func presenceLastSeen(_ date: String) -> String {
        format("presence.lastSeen", date)
    }

    static func recorderWriteFailed(_ description: String) -> String {
        format("recorder.writeFailed", description)
    }

    static func deactivateFallback(_ email: String) -> String {
        format("legal.deactivateFallback", email)
    }

    static func consentBody(_ email: String) -> String {
        format("legal.consent.body", email)
    }

    // MARK: - Private

    private static func t(_ key: String) -> String {
        NSLocalizedString(
            key,
            tableName: "Localizable",
            bundle: LocalizationStore.shared.bundle,
            value: key,
            comment: ""
        )
    }

    private static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), locale: LocalizationStore.shared.locale, arguments: args)
    }
}
