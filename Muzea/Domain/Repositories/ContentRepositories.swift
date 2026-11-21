import Foundation

/// Контракты контентных фич (новости, видео) на основном бэкенде.

protocol NewsRepository {
    func getNews(page: Int, size: Int) async throws -> Page<News>
    func getNewsById(_ id: Int64) async throws -> News
    func createNews(title: String, content: String, videoId: Int64?, image: UploadFile?) async throws -> NewsCreateResponse
    func deleteNews(_ id: Int64) async throws
}

protocol VideoRepository {
    func getVideos() async throws -> [Video]
    func cachedVideos() -> [Video]
    func getVideoById(_ id: Int64) async throws -> Video
    func uploadVideo(
        title: String,
        description: String?,
        data: Data,
        fileName: String,
        mimeType: String,
        thumbnail: UploadFile?
    ) async throws -> Video
    func uploadVideo(
        title: String,
        description: String?,
        data: Data,
        fileName: String,
        mimeType: String,
        thumbnail: UploadFile?,
        onProgress: @escaping (Int) -> Void
    ) async throws -> Video
    func deleteVideo(_ id: Int64) async throws
}

extension VideoRepository {
    /// Фейки и старые реализации не обязаны поддерживать прогресс: по
    /// умолчанию отдаём 0/100 вокруг обычной загрузки.
    func uploadVideo(
        title: String,
        description: String?,
        data: Data,
        fileName: String,
        mimeType: String,
        thumbnail: UploadFile?,
        onProgress: @escaping (Int) -> Void
    ) async throws -> Video {
        onProgress(0)
        let video = try await uploadVideo(
            title: title,
            description: description,
            data: data,
            fileName: fileName,
            mimeType: mimeType,
            thumbnail: thumbnail
        )
        onProgress(100)
        return video
    }
}

extension VideoRepository {
    func uploadVideo(
        title: String,
        description: String?,
        data: Data,
        fileName: String,
        mimeType: String
    ) async throws -> Video {
        try await uploadVideo(
            title: title,
            description: description,
            data: data,
            fileName: fileName,
            mimeType: mimeType,
            thumbnail: nil
        )
    }
}
