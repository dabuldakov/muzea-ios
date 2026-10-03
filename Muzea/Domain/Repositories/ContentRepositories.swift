import Foundation

/// Контракты контентных фич (новости, видео) на основном бэкенде.

protocol NewsRepository {
    func getNews(page: Int, size: Int) async throws -> PageResponse<NewsResponse>
    func getNewsById(_ id: Int64) async throws -> NewsResponse
    func createNews(title: String, content: String, videoId: Int64?, image: UploadFile?) async throws -> NewsCreateResponse
    func deleteNews(_ id: Int64) async throws
}

protocol VideoRepository {
    func getVideos() async throws -> [VideoResponse]
    func cachedVideos() -> [VideoResponse]
    func getVideoById(_ id: Int64) async throws -> VideoResponse
    func uploadVideo(
        title: String,
        description: String?,
        data: Data,
        fileName: String,
        mimeType: String,
        thumbnail: UploadFile?
    ) async throws -> VideoResponse
    func deleteVideo(_ id: Int64) async throws
}

extension VideoRepository {
    func uploadVideo(
        title: String,
        description: String?,
        data: Data,
        fileName: String,
        mimeType: String
    ) async throws -> VideoResponse {
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
