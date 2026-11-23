import Foundation

/// Загрузка вложений в переписке: очередь на диске, прогресс, повторы и
/// удаление. Состоянием владеет ViewModel, сюда передаются доступ и мутация.
@MainActor
final class ChatAttachmentUploader {

    private let chatUuid: String
    private let services: ChatConversationServices
    private let state: () -> ChatConversationUiState
    private let mutate: ((inout ChatConversationUiState) -> Void) -> Void
    private var retrying = false

    init(
        chatUuid: String,
        services: ChatConversationServices,
        state: @escaping () -> ChatConversationUiState,
        mutate: @escaping ((inout ChatConversationUiState) -> Void) -> Void
    ) {
        self.chatUuid = chatUuid
        self.services = services
        self.state = state
        self.mutate = mutate
    }

    func upload(
        data: Data,
        fileName: String,
        mimeType: String,
        kind: AttachmentKind,
        thumbnail: Data?,
        width: Int?,
        height: Int?,
        duration: Int?
    ) async {
        guard state().pendingAttachments.count < AttachmentPolicy.maxAttachmentsPerMessage else {
            mutate { $0.error = L10n.attachmentLimit(AttachmentPolicy.maxAttachmentsPerMessage) }
            return
        }
        if let message = AttachmentPolicy.validationError(
            fileName: fileName,
            size: Int64(data.count)
        ) {
            mutate { $0.error = message }
            return
        }

        let id = UUID().uuidString
        let pending = PendingChatAttachment(
            id: id,
            fileName: fileName,
            kind: kind,
            uploaded: nil
        )
        mutate {
            $0.pendingAttachments.append(pending)
            $0.isUploadingAttachments = true
        }

        let record = StoredPendingAttachment(
            id: id,
            chatUuid: chatUuid,
            fileName: fileName,
            mimeType: mimeType,
            kind: kind.rawValue,
            width: width,
            height: height,
            duration: duration,
            filePath: "",
            thumbnailPath: nil,
            uploaded: nil
        )
        try? services.pendingAttachments.save(
            record: record,
            data: data,
            thumbnail: thumbnail
        )
        let stored = services.pendingAttachments.load(chatUuid: chatUuid)
            .first { $0.id == id } ?? record

        await performUpload(id: id, record: stored, data: data, thumbnail: thumbnail)
        refreshUploadingFlag()
    }

    func remove(id: String) {
        services.pendingAttachments.remove(id: id)
        mutate {
            $0.pendingAttachments.removeAll { $0.id == id }
            $0.isUploadingAttachments = $0.pendingAttachments.contains { $0.isUploading }
        }
    }

    /// Повторная загрузка одного файла — по тапу на ошибку, как на Android.
    func retry(id: String) async {
        guard let record = services.pendingAttachments.load(chatUuid: chatUuid)
            .first(where: { $0.id == id }), record.uploaded == nil else { return }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: record.filePath)) else {
            remove(id: id)
            return
        }
        let thumbnail = record.thumbnailPath.flatMap { path in
            try? Data(contentsOf: URL(fileURLWithPath: path))
        }
        mutate {
            if let index = $0.pendingAttachments.firstIndex(where: { $0.id == id }) {
                $0.pendingAttachments[index].error = nil
                $0.pendingAttachments[index].progress = 0
            }
            $0.isUploadingAttachments = true
        }
        await performUpload(id: id, record: record, data: data, thumbnail: thumbnail)
        refreshUploadingFlag()
    }

    /// Догружает вложения, выбранные до перезапуска приложения.
    func retryPending() async {
        guard !retrying else { return }
        let stored = services.pendingAttachments.load(chatUuid: chatUuid)
            .filter { $0.uploaded == nil }
        guard !stored.isEmpty else { return }
        retrying = true
        defer { retrying = false }
        mutate { $0.isUploadingAttachments = true }

        for item in stored {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: item.filePath)) else {
                remove(id: item.id)
                continue
            }
            let thumbnail = item.thumbnailPath.flatMap { path in
                try? Data(contentsOf: URL(fileURLWithPath: path))
            }
            await performUpload(id: item.id, record: item, data: data, thumbnail: thumbnail)
        }
        refreshUploadingFlag()
    }

    /// Обновление прогресса одного файла; адресно и с зажимом значений.
    func updateProgress(id: String, progress: Double) {
        mutate {
            guard let index = $0.pendingAttachments.firstIndex(where: { $0.id == id }) else {
                return
            }
            $0.pendingAttachments[index].progress = progress
        }
    }

    /// Одна загрузка: прогресс обновляет только свой файл, ошибка тоже локальна.
    private func performUpload(
        id: String,
        record: StoredPendingAttachment,
        data: Data,
        thumbnail: Data?
    ) async {
        let request = AttachmentUploadRequest(
            chatUuid: chatUuid,
            data: data,
            fileName: record.fileName,
            mimeType: record.mimeType,
            kind: AttachmentKind(rawValue: record.kind) ?? .document,
            thumbnail: thumbnail,
            width: record.width,
            height: record.height,
            duration: record.duration,
            onProgress: { [weak self] progress in
                Task { @MainActor in
                    self?.updateProgress(id: id, progress: progress)
                }
            }
        )

        do {
            let uploaded = try await services.attachments.upload(request)
            var stored = record
            stored.uploaded = uploaded
            services.pendingAttachments.update(stored)
            mutate {
                if let index = $0.pendingAttachments.firstIndex(where: { $0.id == id }) {
                    $0.pendingAttachments[index].uploaded = uploaded
                    $0.pendingAttachments[index].error = nil
                    $0.pendingAttachments[index].progress = 1
                }
            }
        } catch {
            ErrorReporter.logCaught("ChatUpload", error)
            // Файл остаётся в дисковой очереди: повтор — тапом по вложению.
            let message = error.localizedDescription
            mutate {
                if let index = $0.pendingAttachments.firstIndex(where: { $0.id == id }) {
                    $0.pendingAttachments[index].error = message
                } else {
                    $0.error = message
                }
            }
        }
    }

    private func refreshUploadingFlag() {
        mutate {
            $0.isUploadingAttachments = $0.pendingAttachments.contains { $0.isUploading }
        }
    }
}
