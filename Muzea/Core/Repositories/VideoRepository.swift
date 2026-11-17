import Foundation

/// Реализация `VideoRepository` на основном бэкенде с in-memory кэшем списка.
final class VideoRepositoryImpl: VideoRepository {
    private let client: HTTPClient
    private let cache: VideoListCache

    init(client: HTTPClient, cache: VideoListCache) {
        self.client = client
        self.cache = cache
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
        let dto: VideoDTO = try await client.upload(
            "/api/videos/upload",
            fields: fields,
            files: files
        )
        return dto.toDomain()
    }

    func deleteVideo(_ id: Int64) async throws {
        try await client.requestVoid("DELETE", "/api/videos/\(id)")
    }
}
