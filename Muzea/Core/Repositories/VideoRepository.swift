import Foundation

/// Реализация `VideoRepository` на основном бэкенде с in-memory кэшем списка.
final class VideoRepositoryImpl: VideoRepository {
    private let client: HTTPClient
    private let cache: VideoListCache
    private let presignedUploader: PresignedUploader

    init(
        client: HTTPClient,
        cache: VideoListCache,
        presignedUploader: PresignedUploader = PresignedUploader()
    ) {
        self.client = client
        self.cache = cache
        self.presignedUploader = presignedUploader
    }

    func getVideos() async throws -> [Video] {
        let dtos: [VideoDTO] = try await client.request("GET", "/api/videos")
        let videos = dtos.map { $0.toDomain() }
        cache.put(videos)
        return videos
    }

    func cachedVideos() -> [Video] {
        cache.get()
    }

    func getVideoById(_ id: Int64) async throws -> Video {
        let dto: VideoDTO = try await client.request("GET", "/api/videos/\(id)")
        return dto.toDomain()
    }

    func uploadVideo(
        title: String,
        description: String?,
        data: Data,
        fileName: String,
        mimeType: String,
        thumbnail: UploadFile?
    ) async throws -> Video {
        try await uploadVideo(
            title: title,
            description: description,
            data: data,
            fileName: fileName,
            mimeType: mimeType,
            thumbnail: thumbnail,
            onProgress: { _ in }
        )
    }

    /// Presigned PUT в MinIO: presign → загрузка файла напрямую → finalize.
    /// При 503 (на сервере не настроен публичный MinIO) — старый multipart.
    func uploadVideo(
        title: String,
        description: String?,
        data: Data,
        fileName: String,
        mimeType: String,
        thumbnail: UploadFile?,
        onProgress: @escaping (Int) -> Void
    ) async throws -> Video {
        do {
            let ticket: PresignUploadResponse = try await client.request(
                "POST",
                "/api/videos/presign-upload",
                body: PresignUploadRequest(
                    contentType: mimeType,
                    size: Int64(data.count)
                )
            )
            guard let uploadURL = URL(string: ticket.uploadUrl) else {
                throw APIError.invalidURL
            }
            try await presignedUploader.put(
                data: data,
                to: uploadURL,
                contentType: mimeType,
                onProgress: onProgress
            )
            let dto: VideoDTO = try await client.request(
                "POST",
                "/api/videos",
                body: FinalizeVideoUploadRequest(
                    objectKey: ticket.objectKey,
                    title: title,
                    description: description
                )
            )
            return dto.toDomain()
        } catch let APIError.server(code, _) where code == 503 {
            return try await uploadMultipart(
                title: title,
                description: description,
                data: data,
                fileName: fileName,
                mimeType: mimeType,
                thumbnail: thumbnail,
                onProgress: onProgress
            )
        }
    }

    /// Запасной путь для серверов без публичного MinIO.
    private func uploadMultipart(
        title: String,
        description: String?,
        data: Data,
        fileName: String,
        mimeType: String,
        thumbnail: UploadFile?,
        onProgress: @escaping (Int) -> Void
    ) async throws -> Video {
        var fields = ["title": title]
        if let description, !description.isEmpty { fields["description"] = description }

        var files = [
            MultipartFile(field: "file", fileName: fileName, mimeType: mimeType, data: data)
        ]
        if let thumbnail {
            files.append(
                MultipartFile(
                    field: "thumbnail",
                    fileName: thumbnail.fileName,
                    mimeType: thumbnail.mimeType,
                    data: thumbnail.data
                )
            )
        }
        onProgress(0)
        let dto: VideoDTO = try await client.upload(
            "/api/videos/upload",
            fields: fields,
            files: files
        )
        onProgress(100)
        return dto.toDomain()
    }

    func deleteVideo(_ id: Int64) async throws {
        try await client.requestVoid("DELETE", "/api/videos/\(id)")
    }
}
