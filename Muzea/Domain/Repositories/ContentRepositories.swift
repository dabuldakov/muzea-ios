import Foundation

/// Контракты контентных фич (новости, видео) на основном бэкенде.

protocol NewsRepository {
    func getNews(page: Int, size: Int) async throws -> Page<News>
    func getNewsById(_ id: Int64) async throws -> News
    func createNews(title: String, content: String, videoId: Int64?, image: UploadFile?) async throws -> NewsCreateResponse
    func updateNews(
        id: Int64,
        title: String,
        content: String,
        videoId: Int64?,
        removeVideo: Bool,
        image: UploadFile?,
        removeImage: Bool
    ) async throws -> News
    func deleteNews(_ id: Int64) async throws
    func likeNews(_ id: Int64) async throws -> Int64
    func unlikeNews(_ id: Int64) async throws -> Int64
    func likedNewsIds() async throws -> Set<Int64>
    func registerNewsView(_ id: Int64) async
    func getNewsComments(_ newsId: Int64, before: Int64?, size: Int) async throws -> NewsCommentsPage
    func addNewsComment(_ newsId: Int64, content: String) async throws -> NewsComment
    func deleteNewsComment(_ newsId: Int64, commentId: Int64) async throws
}

extension NewsRepository {
    func updateNews(
        id: Int64,
        title: String,
        content: String,
        videoId: Int64?,
        removeVideo: Bool,
        image: UploadFile?,
        removeImage: Bool
    ) async throws -> News {
        throw APIError.server(-1, "updateNews is not implemented")
    }

    func likeNews(_ id: Int64) async throws -> Int64 {
        throw APIError.server(-1, "likeNews is not implemented")
    }

    func unlikeNews(_ id: Int64) async throws -> Int64 {
        throw APIError.server(-1, "unlikeNews is not implemented")
    }

    func likedNewsIds() async throws -> Set<Int64> { [] }

    func registerNewsView(_ id: Int64) async {}

    func getNewsComments(_ newsId: Int64, before: Int64?, size: Int) async throws -> NewsCommentsPage {
        NewsCommentsPage(comments: [], total: 0, hasMore: false, nextBefore: nil)
    }

    func addNewsComment(_ newsId: Int64, content: String) async throws -> NewsComment {
        throw APIError.server(-1, "addNewsComment is not implemented")
    }

    func deleteNewsComment(_ newsId: Int64, commentId: Int64) async throws {
        throw APIError.server(-1, "deleteNewsComment is not implemented")
    }
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
