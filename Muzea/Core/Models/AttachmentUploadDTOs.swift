import Foundation

/// Контракт presigned-загрузки вложений чата (presign → PUT → finalize),
/// как `AttachmentUploadDtos` на Android.
struct PresignAttachmentRequest: Encodable {
    let chatUuid: String
    let fileName: String
    let contentType: String?
    let size: Int64
    /// ATTACHMENT или THUMBNAIL.
    let kind: String
}

struct PresignAttachmentResponse: Decodable {
    let uploadUrl: String
    let objectKey: String
    let expiresInSeconds: Int?
}

struct FinalizeAttachmentRequest: Encodable {
    let chatUuid: String
    let objectKey: String
    let thumbnailKey: String?
    let fileName: String
    let width: Int?
    let height: Int?
    let duration: Int?
}
