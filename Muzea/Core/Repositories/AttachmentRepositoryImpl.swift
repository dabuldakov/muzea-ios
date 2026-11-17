import Foundation

/// Загрузка orphan-вложений и скачивание через прокси бэкенда.
final class AttachmentRepositoryImpl: AttachmentRepository {
    private let auth: ChatAuthorization

    init(auth: ChatAuthorization) {
        self.auth = auth
    }

    func upload(
        chatUuid: String,
        data: Data,
        fileName: String,
        mimeType: String,
        kind: AttachmentKind,
        thumbnail: Data?,
        width: Int?,
        height: Int?,
        duration: Int?
    ) async throws -> ChatAttachment {
        var fields = ["chatUuid": chatUuid]
        if let width { fields["width"] = String(width) }
        if let height { fields["height"] = String(height) }
        if let duration { fields["duration"] = String(duration) }

        var files = [
            MultipartFile(
                field: "file",
                fileName: fileName,
                mimeType: mimeType,
                data: data
            )
        ]
        if let thumbnail, kind == .image {
            files.append(MultipartFile(
                field: "thumbnail",
                fileName: "thumb.jpg",
                mimeType: "image/jpeg",
                data: thumbnail
            ))
        }

        return try await auth.authorized {
            try await auth.client.upload(
                "/api/attachments/upload",
                fields: fields,
                files: files
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
