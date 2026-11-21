import Foundation

/// Контракт прямой загрузки видео в MinIO (presign → PUT → finalize),
/// как на Android в `PresignUploadRequest` / `FinalizeVideoUploadRequest`.
struct PresignUploadRequest: Encodable {
    let contentType: String
    let size: Int64
}

struct PresignUploadResponse: Decodable {
    let uploadUrl: String
    let objectKey: String
    let expiresInSeconds: Int?
}

struct FinalizeVideoUploadRequest: Encodable {
    let objectKey: String
    let title: String
    let description: String?
}
