import XCTest
import UIKit
@testable import Muzea

final class AttachmentPolicyTests: XCTestCase {

    func testKnownTypesAndLimits() {
        XCTAssertEqual(AttachmentPolicy.rule(for: "photo.JPG")?.kind, .image)
        XCTAssertEqual(AttachmentPolicy.rule(for: "clip.mov")?.kind, .video)
        XCTAssertEqual(AttachmentPolicy.rule(for: "voice.m4a")?.kind, .audio)
        XCTAssertEqual(AttachmentPolicy.rule(for: "doc.pdf")?.kind, .document)
        XCTAssertNil(AttachmentPolicy.rule(for: "app.exe"))
    }

    func testValidationErrors() {
        XCTAssertNil(AttachmentPolicy.validationError(fileName: "a.jpg", size: 10))
        XCTAssertNotNil(AttachmentPolicy.validationError(fileName: "a.exe", size: 10))
        XCTAssertNotNil(AttachmentPolicy.validationError(fileName: "a.jpg", size: 0))
        XCTAssertNotNil(AttachmentPolicy.validationError(
            fileName: "a.jpg",
            size: AttachmentPolicy.maxImageBytes + 1
        ))
    }

    func testMessageTypeFromKinds() {
        XCTAssertEqual(AttachmentPolicy.messageType(for: []), "TEXT")
        XCTAssertEqual(AttachmentPolicy.messageType(for: [.image, .image]), "IMAGE")
        XCTAssertEqual(AttachmentPolicy.messageType(for: [.video]), "VIDEO")
        XCTAssertEqual(AttachmentPolicy.messageType(for: [.audio]), "AUDIO")
        XCTAssertEqual(AttachmentPolicy.messageType(for: [.image, .document]), "FILE")
        XCTAssertEqual(AttachmentPolicy.messageType(for: [.gif]), "GIF")
    }

    func testAttachmentKindFallsBackToFileName() {
        XCTAssertEqual(AttachmentPolicy.kind(of: Self.attachment(type: "IMAGE")), .image)
        XCTAssertEqual(AttachmentPolicy.kind(of: Self.attachment(type: "FILE")), .document)
        XCTAssertEqual(
            AttachmentPolicy.kind(of: Self.attachment(type: nil, fileName: "voice.m4a")),
            .audio
        )
        XCTAssertEqual(AttachmentPolicy.kind(of: Self.attachment(type: nil, fileName: nil)), .document)
    }

    func testPendingAttachmentAccessibilityLabel() {
        var pending = PendingChatAttachment(
            id: "a",
            fileName: "photo.jpg",
            kind: .image
        )
        XCTAssertEqual(pending.accessibilityLabel(), "photo.jpg")

        pending.progress = 0.42
        XCTAssertEqual(pending.accessibilityLabel(), "photo.jpg, 42%")

        pending.error = "boom"
        XCTAssertEqual(pending.accessibilityLabel(), "photo.jpg, boom")
    }

    func testImagesFilterKeepsOnlyImages() {
        let attachments = [
            Self.attachment(type: "IMAGE", uuid: "a"),
            Self.attachment(type: "VIDEO", uuid: "b"),
            Self.attachment(type: nil, fileName: "x.jpg", uuid: "c")
        ]

        XCTAssertEqual(AttachmentPolicy.images(in: attachments).map(\.attachmentUuid), ["a", "c"])
        XCTAssertTrue(AttachmentPolicy.images(in: []).isEmpty)
    }

    private static func attachment(
        type: String?,
        fileName: String? = "photo.jpg",
        uuid: String? = "a-1"
    ) -> ChatAttachment {
        ChatAttachment(
            attachmentUuid: uuid,
            fileName: fileName,
            fileUrl: nil,
            thumbnailUrl: nil,
            mp4Url: nil,
            fileSize: nil,
            mimeType: nil,
            type: type,
            width: nil,
            height: nil,
            duration: nil,
            gifKey: nil
        )
    }

    func testServerTypeMapping() {
        XCTAssertEqual(AttachmentPolicy.kind(fromServerType: "FILE"), .document)
        XCTAssertEqual(AttachmentPolicy.kind(fromServerType: "IMAGE"), .image)
        XCTAssertNil(AttachmentPolicy.kind(fromServerType: "UNKNOWN"))
    }

    func testAttachmentURLsPreferProxyUUID() {
        let attachment = ChatAttachment(
            attachmentUuid: "a-1",
            fileName: "photo.jpg",
            fileUrl: "minio-key",
            thumbnailUrl: "thumb-key",
            mp4Url: nil,
            fileSize: 10,
            mimeType: "image/jpeg",
            type: "IMAGE",
            width: nil,
            height: nil,
            duration: nil,
            gifKey: nil
        )

        XCTAssertEqual(
            AttachmentURLResolver.fileURL(for: attachment)?.absoluteString,
            "https://chat-muzea.su/api/attachments/a-1"
        )
        XCTAssertEqual(
            AttachmentURLResolver.previewURL(for: attachment)?.absoluteString,
            "https://chat-muzea.su/api/attachments/a-1/preview"
        )
    }

    func testAbsoluteAndRelativeFallbacks() {
        XCTAssertEqual(
            AttachmentURLResolver.absolute("https://cdn.example/a.jpg", base: Config.chatBaseURL)?.absoluteString,
            "https://cdn.example/a.jpg"
        )
        XCTAssertEqual(
            AttachmentURLResolver.absolute("/api/avatars/a.png", base: Config.chatBaseURL)?.absoluteString,
            "https://chat-muzea.su/api/avatars/a.png"
        )
        XCTAssertNil(AttachmentURLResolver.absolute(nil, base: Config.chatBaseURL))
    }

    func testImagePreparationDownscalesAndEncodesJPEG() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 1000))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3000, height: 1000))
        }
        let original = try XCTUnwrap(image.jpegData(compressionQuality: 1))

        let prepared = try XCTUnwrap(ImagePreparation.jpeg(from: original))

        XCTAssertEqual(prepared.width, 2048)
        XCTAssertEqual(prepared.height, 683)
        XCTAssertEqual(Array(prepared.data.prefix(2)), [0xFF, 0xD8])
    }

    func testFileNamesAreSanitized() {
        XCTAssertEqual(AttachmentFiles.sanitize("../etc/passwd"), ".._etc_passwd")
        XCTAssertEqual(AttachmentFiles.sanitize(""), "attachment")
    }

    func testDurationFormatting() {
        XCTAssertEqual(DurationFormatter.mmss(0), "0:00")
        XCTAssertEqual(DurationFormatter.mmss(65), "1:05")
        XCTAssertEqual(DurationFormatter.mmss(3661), "1:01:01")
        XCTAssertEqual(DurationFormatter.mmss(-5), "0:00")
    }

    func testFileCacheDownloadsOnceAndReusesLocalURL() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-\(UUID().uuidString)", isDirectory: true)
        let cache = AttachmentFileCache(directory: directory)
        let repository = FakeAttachmentRepository()
        repository.downloadData = Data([1, 2, 3, 4])

        let first = await cache.localURL(
            attachmentUuid: "a-1",
            fileName: "clip.mp4",
            repository: repository
        )
        let second = await cache.localURL(
            attachmentUuid: "a-1",
            fileName: "clip.mp4",
            repository: repository
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(repository.downloads, 1)
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(first)), Data([1, 2, 3, 4]))
    }
}

final class AttachmentRepositoryTests: XCTestCase {

    private var store: TokenStore!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        store = TestSupport.makeStore()
        store.token = "access"
        store.chatUserUuid = "me"
    }

    override func tearDown() {
        MockURLProtocol.reset()
        store = nil
        super.tearDown()
    }

    private func repository() -> AttachmentRepositoryImpl {
        let client = TestSupport.chatClient(tokenStore: store)
        return AttachmentRepositoryImpl(
            auth: ChatAuthorization(
                client: client,
                auth: ChatAuthManager(client: client, store: store)
            )
        )
    }

    func testUploadSendsMultipartFieldsAndFile() async throws {
        MockURLProtocol.handler = { request in
            (
                MockURLProtocol.response(for: request),
                TestSupport.data(#"{"attachmentUuid":"a-1","type":"IMAGE","fileUrl":"key"}"#)
            )
        }

        let uploaded = try await repository().upload(
            AttachmentUploadRequest(
                chatUuid: "c-1",
                data: Data([0xFF, 0xD8, 0xFF]),
                fileName: "photo.jpg",
                mimeType: "image/jpeg",
                kind: .image,
                thumbnail: Data([0xFF, 0xD8, 0xFF]),
                width: 10,
                height: 20,
                duration: nil
            )
        )

        XCTAssertEqual(uploaded.attachmentUuid, "a-1")
        let request = try XCTUnwrap(MockURLProtocol.requests.first)
        let body = String(decoding: request.capturedBody ?? Data(), as: UTF8.self)
        XCTAssertTrue(body.contains("name=\"chatUuid\""))
        XCTAssertTrue(body.contains("c-1"))
        XCTAssertTrue(body.contains("name=\"width\""))
        XCTAssertTrue(body.contains("photo.jpg"))
        XCTAssertTrue(body.contains("name=\"thumbnail\""))
    }

    func testDocumentUploadDoesNotSendThumbnail() async throws {
        MockURLProtocol.handler = { request in
            (
                MockURLProtocol.response(for: request),
                TestSupport.data(#"{"attachmentUuid":"a-2","type":"FILE"}"#)
            )
        }

        _ = try await repository().upload(
            AttachmentUploadRequest(
                chatUuid: "c-1",
                data: Data([1, 2, 3]),
                fileName: "report.pdf",
                mimeType: "application/pdf",
                kind: .document,
                thumbnail: Data([9, 9])
            )
        )

        let body = String(
            decoding: MockURLProtocol.requests.first?.capturedBody ?? Data(),
            as: UTF8.self
        )
        XCTAssertFalse(body.contains("name=\"thumbnail\""))
        XCTAssertTrue(body.contains("report.pdf"))
    }

    func testPreviewUsesPreviewEndpoint() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), Data([1, 2, 3]))
        }

        _ = try await repository().preview(attachmentUuid: "a-1")

        XCTAssertEqual(
            MockURLProtocol.requests.first?.url?.path,
            "/api/attachments/a-1/preview"
        )
    }

    func testSendMediaPostsTypeAndAttachmentUUIDs() async throws {
        MockURLProtocol.handler = { request in
            (
                MockURLProtocol.response(for: request),
                TestSupport.data(#"{"messageUuid":"m1","messageId":5,"messageType":"IMAGE"}"#)
            )
        }
        let client = TestSupport.chatClient(tokenStore: store)
        let messages = MessageRepositoryImpl(
            auth: ChatAuthorization(
                client: client,
                auth: ChatAuthManager(client: client, store: store)
            ),
            cache: ChatMessagesCache()
        )

        _ = try await messages.sendMessage(
            chatUuid: "c-1",
            text: "caption",
            messageType: "IMAGE",
            replyToMessageUuid: nil,
            clientMessageId: "client-1",
            attachments: ["a-1"],
            power: 0
        )

        let request = try XCTUnwrap(MockURLProtocol.requests.first)
        let json = request.capturedBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        }
        XCTAssertEqual(json?["messageType"] as? String, "IMAGE")
        XCTAssertEqual(json?["attachments"] as? [String], ["a-1"])
    }
}

@MainActor
final class ImagePreparationTests: XCTestCase {

    func testInvalidDataReturnsNil() {
        XCTAssertNil(ImagePreparation.jpeg(from: Data([0, 1, 2])))
    }

    func testLargeImageIsScaledToMaxDimension() throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 1000)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3000, height: 1000))
        }
        let data = try XCTUnwrap(source.jpegData(compressionQuality: 0.9))

        let prepared = try XCTUnwrap(ImagePreparation.jpeg(from: data))

        XCTAssertEqual(prepared.width, 2048)
        XCTAssertEqual(prepared.height, 683)
        XCTAssertFalse(prepared.data.isEmpty)
        XCTAssertNotNil(UIImage(data: prepared.data))
    }

    func testSmallImageKeepsSize() throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 50)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 50))
        }
        let data = try XCTUnwrap(source.jpegData(compressionQuality: 0.9))

        let prepared = try XCTUnwrap(ImagePreparation.jpeg(from: data))

        XCTAssertEqual(prepared.width, 100)
        XCTAssertEqual(prepared.height, 50)
    }
}

final class AttachmentFilesTests: XCTestCase {

    func testSanitizeKeepsSafeCharactersOnly() {
        XCTAssertEqual(AttachmentFiles.sanitize("../../etc/passwd"), ".._.._etc_passwd")
        XCTAssertEqual(AttachmentFiles.sanitize("photo 1.jpg"), "photo 1.jpg")
        XCTAssertEqual(AttachmentFiles.sanitize(""), "attachment")
    }

    func testWriteUsesSanitizedName() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("attachment-files-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = try XCTUnwrap(
            AttachmentFiles.write(data: Data([1, 2]), fileName: "../a b.jpg", directory: directory)
        )

        XCTAssertEqual(url.lastPathComponent, ".._a b.jpg")
        XCTAssertEqual(try Data(contentsOf: url), Data([1, 2]))
    }
}

final class WaveformProviderAudioTests: XCTestCase {

    /// Простой PCM WAV: 8 кГц, моно, 16 бит, синус 440 Гц.
    private func wavData(seconds: Double = 0.5, sampleRate: Int = 8000) -> Data {
        let sampleCount = Int(Double(sampleRate) * seconds)
        var samples = Data(capacity: sampleCount * 2)
        for index in 0..<sampleCount {
            let value = sin(2 * Double.pi * 440 * Double(index) / Double(sampleRate))
            let sample = Int16(max(-1, min(1, value)) * 20000)
            withUnsafeBytes(of: sample.littleEndian) { samples.append(contentsOf: $0) }
        }

        func le32(_ value: UInt32) -> Data {
            withUnsafeBytes(of: value.littleEndian) { Data($0) }
        }
        func le16(_ value: UInt16) -> Data {
            withUnsafeBytes(of: value.littleEndian) { Data($0) }
        }

        var data = Data()
        data.append(Data("RIFF".utf8))
        data.append(le32(UInt32(36 + samples.count)))
        data.append(Data("WAVE".utf8))
        data.append(Data("fmt ".utf8))
        data.append(le32(16))
        data.append(le16(1))
        data.append(le16(1))
        data.append(le32(UInt32(sampleRate)))
        data.append(le32(UInt32(sampleRate * 2)))
        data.append(le16(2))
        data.append(le16(16))
        data.append(Data("data".utf8))
        data.append(le32(UInt32(samples.count)))
        data.append(samples)
        return data
    }

    func testWaveformIsBuiltFromRealAudio() async throws {
        let repository = FakeAttachmentRepository()
        repository.downloadData = wavData()
        let attachment = ChatAttachment(
            attachmentUuid: "wav-\(UUID().uuidString)",
            fileName: "voice.wav",
            fileUrl: nil,
            thumbnailUrl: nil,
            mp4Url: nil,
            fileSize: 100,
            mimeType: "audio/wav",
            type: "AUDIO",
            width: nil,
            height: nil,
            duration: 1,
            gifKey: nil
        )

        let waveform = await WaveformProvider.shared.waveform(
            for: attachment,
            repository: repository
        )

        let bars = try XCTUnwrap(waveform)
        XCTAssertEqual(bars.count, Waveform.defaultBarCount)
        XCTAssertTrue(bars.allSatisfy { $0 >= Waveform.minimumLevel && $0 <= 1 })
        XCTAssertGreaterThan(bars.max() ?? 0, Waveform.minimumLevel)
    }
}

final class AudioPreparationTests: XCTestCase {

    func testBrokenDataHasNoDuration() async {
        let duration = await AudioPreparation.durationSeconds(
            data: Data([0, 1, 2]),
            fileName: "broken.mp3"
        )

        XCTAssertNil(duration)
    }
}

final class VideoPreparationTests: XCTestCase {

    func testBrokenDataReturnsEmptyMetadata() async {
        let prepared = await VideoPreparation.prepare(
            data: Data([0, 1, 2, 3]),
            fileName: "broken.mp4"
        )

        XCTAssertNil(prepared.thumbnail)
        XCTAssertNil(prepared.width)
        XCTAssertNil(prepared.height)
        XCTAssertNil(prepared.duration)
    }
}

@MainActor
final class ChatMediaViewModelTests: XCTestCase {

    private func makeViewModel(
        attachmentRepository: FakeAttachmentRepository = FakeAttachmentRepository(),
        pendingStore: FakePendingAttachmentStore = FakePendingAttachmentStore()
    ) -> (ChatConversationViewModel, FakeMessageRepository) {
        let messages = FakeMessageRepository()
        let services = ChatConversationServices.fake(
            messages: messages,
            attachments: attachmentRepository,
            pendingAttachments: pendingStore
        )
        let viewModel = ChatConversationViewModel(
            chatUuid: "c-1",
            myUserUuid: "me",
            isGroupChat: false,
            services: services
        )
        return (viewModel, messages)
    }

    func testImageUploadAppearsAsReadyAttachment() async {
        let attachments = FakeAttachmentRepository()
        let (viewModel, _) = makeViewModel(attachmentRepository: attachments)

        await viewModel.addImage(data: Data([1, 2, 3]), width: 10, height: 20)

        XCTAssertEqual(attachments.uploads.first?.2, .image)
        XCTAssertEqual(viewModel.state.pendingAttachments.count, 1)
        XCTAssertTrue(viewModel.state.pendingAttachments[0].isUploaded)
        XCTAssertFalse(viewModel.state.isUploadingAttachments)
    }

    func testUploadFailureIsLocalToAttachmentAndRetrySucceeds() async throws {
        let attachments = FakeAttachmentRepository()
        attachments.uploadError = APIError.server(500, "boom")
        let store = FakePendingAttachmentStore()
        let (viewModel, _) = makeViewModel(
            attachmentRepository: attachments,
            pendingStore: store
        )

        await viewModel.addImage(data: Data([1, 2, 3]), width: 1, height: 1)

        let failed = try XCTUnwrap(viewModel.state.pendingAttachments.first)
        XCTAssertFalse(failed.isUploaded)
        XCTAssertNotNil(failed.error)
        XCTAssertNil(viewModel.state.error)
        XCTAssertFalse(viewModel.state.isUploadingAttachments)
        XCTAssertEqual(store.records.count, 1)

        attachments.uploadError = nil
        await viewModel.retryPendingAttachment(failed.id)

        let retried = try XCTUnwrap(viewModel.state.pendingAttachments.first)
        XCTAssertTrue(retried.isUploaded)
        XCTAssertNil(retried.error)
        XCTAssertEqual(retried.normalizedProgress, 1)
        XCTAssertEqual(attachments.uploads.count, 2)
        XCTAssertEqual(store.records.first?.uploaded?.attachmentUuid, "a-1")
    }

    func testUploadProgressTargetsOnlyItsAttachmentAndClamps() async throws {
        let (viewModel, _) = makeViewModel()
        await viewModel.addImage(data: Data([1]), width: 1, height: 1)
        let id = try XCTUnwrap(viewModel.state.pendingAttachments.first?.id)

        viewModel.updateUploadProgress(id: id, progress: 0.42)
        XCTAssertEqual(viewModel.state.pendingAttachments[0].normalizedProgress, 0.42)

        viewModel.updateUploadProgress(id: id, progress: 2)
        XCTAssertEqual(viewModel.state.pendingAttachments[0].normalizedProgress, 1)

        viewModel.updateUploadProgress(id: "unknown", progress: 0.5)
        XCTAssertEqual(viewModel.state.pendingAttachments[0].normalizedProgress, 1)
    }

    func testAttachmentLimitRejectsEleventhFile() async {
        let attachments = FakeAttachmentRepository()
        let (viewModel, _) = makeViewModel(attachmentRepository: attachments)

        for _ in 0..<AttachmentPolicy.maxAttachmentsPerMessage {
            await viewModel.addImage(data: Data([1]), width: 1, height: 1)
        }
        await viewModel.addImage(data: Data([1]), width: 1, height: 1)

        XCTAssertEqual(
            viewModel.state.pendingAttachments.count,
            AttachmentPolicy.maxAttachmentsPerMessage
        )
        XCTAssertNotNil(viewModel.state.error)
    }

    func testSendWithoutCaptionUsesImageTypeAndClearsPending() async {
        let attachments = FakeAttachmentRepository()
        let (viewModel, messages) = makeViewModel(attachmentRepository: attachments)
        await viewModel.addImage(data: Data([1, 2, 3]), width: 10, height: 20)
        let remote = try! XCTUnwrap(attachments.response)
        messages.sendResult = TestData.message("server-1")
            .replacing(messageType: "IMAGE", attachments: [remote])

        let ok = await viewModel.send("")

        XCTAssertTrue(ok)
        XCTAssertEqual(messages.sentMedia.first?.messageType, "IMAGE")
        XCTAssertEqual(messages.sentMedia.first?.attachments, ["a-1"])
        XCTAssertTrue(viewModel.state.pendingAttachments.isEmpty)
        XCTAssertEqual(viewModel.state.messages.first?.messageType, "IMAGE")
    }

    func testUnsupportedFileIsRejected() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.addFile(data: Data([1]), fileName: "virus.exe", mimeType: "application/octet-stream")

        XCTAssertTrue(viewModel.state.pendingAttachments.isEmpty)
        XCTAssertNotNil(viewModel.state.error)
    }

    func testFailedMediaSendQueuesMessageWithAttachments() async {
        let attachments = FakeAttachmentRepository()
        let (viewModel, messages) = makeViewModel(attachmentRepository: attachments)
        messages.sendError = APIError.server(500, "boom")
        await viewModel.addImage(data: Data([1, 2, 3]), width: 10, height: 20)

        let ok = await viewModel.send("")

        XCTAssertFalse(ok)
        XCTAssertEqual(viewModel.state.messages.count, 1)
        XCTAssertEqual(viewModel.state.failedMessages.count, 1)
    }

    func testSendVoiceUploadsAudioAndSends() async throws {
        let attachments = FakeAttachmentRepository()
        let (viewModel, messages) = makeViewModel(attachmentRepository: attachments)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-\(UUID().uuidString).m4a")
        try Data([1, 2, 3]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let recorded = RecordedVoice(url: url, data: Data([1, 2, 3]), duration: 3)

        let ok = await viewModel.sendVoice(recorded)

        XCTAssertTrue(ok)
        XCTAssertEqual(attachments.uploads.first?.2, .audio)
        XCTAssertEqual(messages.sentMedia.first?.messageType, "AUDIO")
        XCTAssertEqual(messages.sentMedia.first?.attachments, ["a-1"])
        XCTAssertTrue(viewModel.state.pendingAttachments.isEmpty)
    }

    func testSendGifCreatesGifMessage() async {
        let (viewModel, messages) = makeViewModel()
        let gif = Gif(
            provider: "klipy",
            providerGifId: "g1",
            title: "Cat",
            url: "https://cdn/cat.webp",
            previewUrl: "https://cdn/cat.jpg",
            mp4Url: "https://cdn/cat.mp4",
            width: 200,
            height: 100,
            gifKey: nil
        )

        await viewModel.sendGif(gif)

        XCTAssertEqual(messages.sentGifs.first?.providerGifId, "g1")
        XCTAssertEqual(viewModel.state.messages.first?.messageType, "GIF")
        XCTAssertEqual(viewModel.state.messages.first?.attachments?.first?.type, "GIF")
    }

    func testSendVideoNoteUsesVideoNoteMessageType() async throws {
        let attachments = FakeAttachmentRepository()
        let (viewModel, messages) = makeViewModel(attachmentRepository: attachments)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("note-\(UUID().uuidString).mp4")
        try Data([1, 2, 3]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let note = RecordedVideoNote(
            url: url,
            data: Data([1, 2, 3]),
            thumbnail: Data([4, 5]),
            duration: 5,
            width: 480,
            height: 480,
            fileName: url.lastPathComponent
        )

        let ok = await viewModel.sendVideoNote(note)

        XCTAssertTrue(ok)
        XCTAssertEqual(attachments.uploads.first?.2, .video)
        XCTAssertEqual(messages.sentMedia.first?.messageType, "VIDEO_NOTE")
        XCTAssertEqual(messages.sentMedia.first?.attachments, ["a-1"])
    }

    func testVideoNoteLimits() {
        XCTAssertFalse(VideoNoteLimits.isValid(duration: 0))
        XCTAssertTrue(VideoNoteLimits.isValid(duration: 1))
        XCTAssertTrue(VideoNoteLimits.isValid(duration: 60))
        XCTAssertFalse(VideoNoteLimits.isValid(duration: 62))
        XCTAssertEqual(VideoNoteLimits.clampedDuration(90), 60)
        XCTAssertEqual(VideoNoteLimits.clampedDuration(-1), 0)
    }

    func testPendingAttachmentStoreRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-\(UUID().uuidString)", isDirectory: true)
        let store = FilePendingAttachmentStore(root: root)
        let record = StoredPendingAttachment(
            id: "p1",
            chatUuid: "c1",
            fileName: "photo.jpg",
            mimeType: "image/jpeg",
            kind: AttachmentKind.image.rawValue,
            width: 10,
            height: 20,
            duration: nil,
            filePath: "",
            thumbnailPath: nil,
            uploaded: nil
        )

        try store.save(record: record, data: Data([1, 2, 3]), thumbnail: Data([4]))
        let loaded = try XCTUnwrap(store.load(chatUuid: "c1").first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: loaded.filePath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: loaded.thumbnailPath ?? ""))

        var updated = loaded
        updated.uploaded = ChatAttachment(
            attachmentUuid: "a1",
            fileName: "photo.jpg",
            fileUrl: "key",
            thumbnailUrl: nil,
            mp4Url: nil,
            fileSize: 3,
            mimeType: "image/jpeg",
            type: "IMAGE",
            width: 10,
            height: 20,
            duration: nil,
            gifKey: nil
        )
        store.update(updated)
        XCTAssertEqual(store.load(chatUuid: "c1").first?.uploaded?.attachmentUuid, "a1")

        store.clear(chatUuid: "c1")
        XCTAssertTrue(store.load(chatUuid: "c1").isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: loaded.filePath))
    }

    func testRestoresAndRetriesPendingAttachment() async throws {
        let store = FakePendingAttachmentStore()
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-\(UUID().uuidString).jpg")
        try Data([9, 9]).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        store.records = [
            StoredPendingAttachment(
                id: "p1",
                chatUuid: "c-1",
                fileName: "photo.jpg",
                mimeType: "image/jpeg",
                kind: AttachmentKind.image.rawValue,
                width: 1,
                height: 1,
                duration: nil,
                filePath: file.path,
                thumbnailPath: nil,
                uploaded: nil
            )
        ]
        let attachments = FakeAttachmentRepository()
        let messages = FakeMessageRepository()
        let services = ChatConversationServices.fake(
            messages: messages,
            attachments: attachments,
            pendingAttachments: store
        )
        let viewModel = ChatConversationViewModel(
            chatUuid: "c-1",
            myUserUuid: "me",
            isGroupChat: false,
            services: services
        )

        XCTAssertEqual(viewModel.state.pendingAttachments.count, 1)
        XCTAssertFalse(viewModel.state.pendingAttachments[0].isUploaded)

        await viewModel.retryPendingAttachments()

        XCTAssertTrue(viewModel.state.pendingAttachments[0].isUploaded)
        XCTAssertEqual(store.records.first?.uploaded?.attachmentUuid, "a-1")
    }
}
