import Foundation

/// Загрузка вложений: presigned PUT в MinIO, с fallback на multipart.
final class AttachmentRepositoryImpl: AttachmentRepository {
    private let auth: ChatAuthorization
    private let presignedUploader: PresignedUploader

    init(
        auth: ChatAuthorization,
        presignedUploader: PresignedUploader = PresignedUploader()
    ) {
        self.auth = auth
        self.presignedUploader = presignedUploader
    }

    func upload(_ request: AttachmentUploadRequest) async throws -> ChatAttachment {
        do {
            let ticket: PresignAttachmentResponse = try await auth.authorized {
                try await auth.client.request(
                    "POST",
                    "/api/attachments/presign-upload",
                    body: PresignAttachmentRequest(
                        chatUuid: request.chatUuid,
                        fileName: request.fileName,
                        contentType: request.mimeType,
                        size: Int64(request.data.count),
                        kind: "ATTACHMENT"
                    )
                )
            }
            guard let uploadURL = URL(string: ticket.uploadUrl) else {
                throw APIError.invalidURL
            }
            try await presignedUploader.put(
                data: request.data,
                to: uploadURL,
                contentType: request.mimeType,
                onProgress: { percent in
                    request.onProgress?(Double(percent) / 100)
                }
            )

            let thumbnailKey = await uploadThumbnail(request)
            let dto: ChatAttachmentDTO = try await auth.authorized {
                try await auth.client.request(
                    "POST",
                    "/api/attachments",
                    body: FinalizeAttachmentRequest(
                        chatUuid: request.chatUuid,
                        objectKey: ticket.objectKey,
                        thumbnailKey: thumbnailKey,
                        fileName: request.fileName,
                        width: request.width,
                        height: request.height,
                        duration: request.duration
                    )
                )
            }
            return dto.toDomain()
        } catch let APIError.server(code, _) where code == 503 {
            return try await uploadMultipart(request)
        }
    }

    /// Превью необязательно: без него сообщение всё равно отправится.
    private func uploadThumbnail(_ request: AttachmentUploadRequest) async -> String? {
        guard let thumbnail = request.thumbnail,
              request.kind == .image || request.kind == .video else { return nil }
        do {
            let ticket: PresignAttachmentResponse = try await auth.authorized {
                try await auth.client.request(
                    "POST",
                    "/api/attachments/presign-upload",
                    body: PresignAttachmentRequest(
                        chatUuid: request.chatUuid,
                        fileName: "thumb.jpg",
                        contentType: "image/jpeg",
                        size: Int64(thumbnail.count),
                        kind: "THUMBNAIL"
                    )
                )
            }
            guard let url = URL(string: ticket.uploadUrl) else { return nil }
            try await presignedUploader.put(
                data: thumbnail,
                to: url,
                contentType: "image/jpeg",
                onProgress: { _ in }
            )
            return ticket.objectKey
        } catch {
            ErrorReporter.logCaught("AttachmentThumbnail", error)
            return nil
        }
    }

    /// Запасной путь для стендов без публичного MinIO.
    private func uploadMultipart(_ request: AttachmentUploadRequest) async throws -> ChatAttachment {
        var fields = ["chatUuid": request.chatUuid]
        if let width = request.width { fields["width"] = String(width) }
        if let height = request.height { fields["height"] = String(height) }
        if let duration = request.duration { fields["duration"] = String(duration) }

        var files = [
            MultipartFile(
                field: "file",
                fileName: request.fileName,
                mimeType: request.mimeType,
                data: request.data
            )
        ]
        if let thumbnail = request.thumbnail,
           request.kind == .image || request.kind == .video {
            files.append(MultipartFile(
                field: "thumbnail",
                fileName: "thumb.jpg",
                mimeType: "image/jpeg",
                data: thumbnail
            ))
        }

        let onProgress = request.onProgress
        return try await auth.authorized {
            try await auth.client.upload(
                "/api/attachments/upload",
                fields: fields,
                files: files,
                onProgress: onProgress
            )
        }
    }

    func download(attachmentUuid: String) async throws -> Data {
        try await auth.authorized {
            try await auth.client.requestData(
                "GET",
                "/api/attachments/\(attachmentUuid)"
            )
        }
    }

    func preview(attachmentUuid: String) async throws -> Data {
        try await auth.authorized {
            try await auth.client.requestData(
                "GET",
                "/api/attachments/\(attachmentUuid)/preview"
            )
        }
    }
}
