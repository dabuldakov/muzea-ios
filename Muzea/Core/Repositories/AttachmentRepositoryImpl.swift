import Foundation

/// Загрузка orphan-вложений и скачивание через прокси бэкенда.
final class AttachmentRepositoryImpl: AttachmentRepository {
    private let auth: ChatAuthorization

    init(auth: ChatAuthorization) {
        self.auth = auth
    }

    func upload(_ request: AttachmentUploadRequest) async throws -> ChatAttachment {
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
