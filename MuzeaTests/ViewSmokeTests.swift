import SwiftUI
import UIKit
import XCTest
@testable import Muzea

/// Smoke-тесты вью: тело каждого экрана должно собираться и раскладываться без
/// краша. Это не UI-тесты с кликами, но они выполняют `body` и ловят падения
/// в SwiftUI-коде, который иначе не покрыт unit-тестами.
@MainActor
final class ViewSmokeTests: XCTestCase {

    private lazy var container = AppContainer()

    private func host<V: View>(_ view: V, file: StaticString = #filePath, line: UInt = #line) {
        let root = view
            .environmentObject(container)
            .environmentObject(AppRouter())
            .environmentObject(Router())
            .environmentObject(container.networkMonitor)
            .environment(\.locale, Locale(identifier: "ru"))
        // ImageRenderer реально вычисляет body (UIHostingController без окна
        // этого не делает), поэтому покрытие View растёт без UI-тестов.
        let renderer = ImageRenderer(content: root.frame(width: 390, height: 844))
        renderer.scale = 1
        _ = renderer.uiImage

        let controller = UIHostingController(rootView: root)
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        XCTAssertNotNil(controller.view, file: file, line: line)
    }

    private func message(
        _ uuid: String = "m-1",
        text: String = "Привет",
        type: String = "TEXT",
        attachments: [ChatAttachment]? = nil,
        senderDeleted: Bool? = false
    ) -> ChatMessage {
        ChatMessage(
            messageUuid: uuid,
            messageId: 1,
            chatUuid: "c-1",
            senderId: 7,
            senderUuid: "u-1",
            senderName: "Аня",
            senderAvatar: nil,
            text: text,
            messageType: type,
            replyToMessageUuid: nil,
            isEdited: false,
            isDeleted: false,
            isPinned: false,
            createdAt: "2026-01-01T00:00:00",
            updatedAt: nil,
            reactions: [MessageReaction(emoji: "👍", count: 2, mine: true, users: [])],
            power: 42,
            attachments: attachments,
            senderDeleted: senderDeleted
        )
    }

    private var imageAttachment: ChatAttachment {
        ChatAttachment(
            attachmentUuid: "a-1",
            fileName: "photo.jpg",
            fileUrl: "key",
            thumbnailUrl: "thumb",
            mp4Url: nil,
            fileSize: 100,
            mimeType: "image/jpeg",
            type: "IMAGE",
            width: 100,
            height: 80,
            duration: nil,
            gifKey: nil
        )
    }

    private var videoAttachment: ChatAttachment {
        ChatAttachment(
            attachmentUuid: "v-1",
            fileName: "clip.mp4",
            fileUrl: "key",
            thumbnailUrl: "thumb",
            mp4Url: nil,
            fileSize: 100,
            mimeType: "video/mp4",
            type: "VIDEO",
            width: 100,
            height: 80,
            duration: 5,
            gifKey: nil
        )
    }

    private var documentAttachment: ChatAttachment {
        ChatAttachment(
            attachmentUuid: "d-1",
            fileName: "report.pdf",
            fileUrl: "key",
            thumbnailUrl: nil,
            mp4Url: nil,
            fileSize: 4096,
            mimeType: "application/pdf",
            type: "FILE",
            width: nil,
            height: nil,
            duration: nil,
            gifKey: nil
        )
    }

    private var audioAttachment: ChatAttachment {
        ChatAttachment(
            attachmentUuid: "a-2",
            fileName: "voice.m4a",
            fileUrl: "key",
            thumbnailUrl: nil,
            mp4Url: nil,
            fileSize: 100,
            mimeType: "audio/mp4",
            type: "AUDIO",
            width: nil,
            height: nil,
            duration: 12,
            gifKey: nil
        )
    }

    func testTabScreensRender() {
        host(MainTabView())
        host(NewsListView(container: container))
        host(ChatListView(container: container))
        host(ContactListView(container: container))
        host(VideoListView(container: container))
        host(ProfileView(container: container))
    }

    func testAuthScreensRender() {
        host(LoginView(container: container))
        host(RegisterView(container: container, email: "user@example.com"))
        host(ConsentView(consent: container.consentManager) {})
    }

    func testChatListAndConversationRender() {
        host(ChatConversationView(
            chat: TestData.chat("c-1"),
            myUserUuid: "me",
            services: ChatConversationServices.fake()
        ))
    }

    func testMessageRowWithAttachmentsRenders() {
        host(MessageRow(
            message: message(),
            isMine: false,
            showSenderName: true,
            replyTarget: nil,
            status: .read,
            isSelected: false,
            myUserUuid: "me",
            onReaction: { _ in },
            onOpenImage: { _ in }
        ))

        host(MessageRow(
            message: message(
                "m-2",
                text: "",
                type: "IMAGE",
                attachments: [imageAttachment, videoAttachment, audioAttachment, documentAttachment]
            ),
            isMine: true,
            showSenderName: false,
            replyTarget: nil,
            status: .sent,
            isSelected: true,
            myUserUuid: "me",
            onReaction: { _ in },
            onOpenImage: nil
        ))
    }

    func testComposerAndAttachmentsRender() {
        var text = ""
        host(ChatComposerView(
            text: Binding(get: { text }, set: { text = $0 }),
            replyTo: nil,
            editing: nil,
            myUserUuid: "me",
            usernames: ["alice"],
            pendingAttachments: [
                PendingChatAttachment(
                    id: "p-1",
                    fileName: "photo.jpg",
                    kind: .image,
                    uploaded: imageAttachment
                ),
                PendingChatAttachment(
                    id: "p-2",
                    fileName: "clip.mp4",
                    kind: .video,
                    uploaded: nil,
                    progress: 0.4
                ),
                PendingChatAttachment(
                    id: "p-3",
                    fileName: "doc.pdf",
                    kind: .document,
                    uploaded: nil,
                    error: "Network error"
                )
            ],
            isUploadingAttachments: true,
            onAttach: {},
            onEmojiGif: {},
            onRemoveAttachment: { _ in },
            onRetryAttachment: { _ in },
            onSend: { _ in },
            onVoiceRecorded: { _ in },
            onVoiceError: { _ in },
            onVideoNote: {},
            onCancel: {}
        ))

        host(MessageAttachmentsView(
            attachments: [imageAttachment, videoAttachment, audioAttachment, documentAttachment],
            isMine: true,
            messageType: "FILE",
            onOpenImage: { _ in }
        ))
    }

    func testSheetsAndPickersRender() {
        host(EmojiGifSheet(repository: FakeGifRepository(), chatUuid: "c-1", onEmoji: { _ in }, onGif: { _ in }))
        host(ForwardChatPickerView(chats: [TestData.chat("c-1")]) { _, _ in })
        host(ReactionPickerSheet(recent: ["👍"], all: ReactionCatalog.all) { _ in })
        host(ReportReasonSheet { _ in })
        host(MessageStatusSheet(
            message: message(),
            receipts: [
                ChatReceipt(
                    userUuid: "u-1",
                    username: "anna",
                    fullName: "Аня",
                    avatarUrl: nil,
                    joinedAt: nil,
                    lastDeliveredMessageId: 1,
                    lastDeliveredAt: "2026-01-01T00:00:00",
                    lastReadMessageId: 1,
                    lastReadAt: "2026-01-01T00:00:01"
                )
            ],
            statuses: [
                MessageStatus(
                    userId: 1,
                    userUuid: "u-1",
                    status: "READ",
                    deliveredAt: "2026-01-01T00:00:00",
                    readAt: "2026-01-01T00:00:01"
                )
            ],
            myUserUuid: "me"
        ))
        host(LinkPreviewView(url: URL(string: "https://muzea.su")!))
        host(VideoNoteRecorderSheet { _ in })
        host(ImageGalleryViewer(
            attachments: [imageAttachment],
            startIndex: 0,
            senderName: "Аня",
            createdAt: "2026-01-01T00:00:00",
            onReply: {},
            onForward: {}
        ))
    }

    func testNewsAndVideoScreensRender() {
        host(CreateNewsView(container: container))
        host(NewsDetailView(newsId: 1, container: container))
        host(VideoUploadView(container: container))
        host(VideoDetailView(
            video: Video(
                id: 1,
                title: "Video",
                description: "Описание",
                url: "/api/videos/stream/1.mp4",
                thumbnailUrl: nil,
                fileSize: nil,
                durationSeconds: 10,
                views: 5,
                likes: 2,
                likedByMe: true,
                uploadedBy: "me",
                uploadedAt: "2026-01-01T00:00:00"
            ),
            container: container
        ))
    }

    func testGroupScreensRender() {
        host(GroupSettingsView(chat: TestData.chat("c-1", type: "GROUP"), container: container))
        host(CreateGroupView(container: container) { _ in })
        host(ShareToChatView(text: "hello", container: container) { _ in })
    }
}
