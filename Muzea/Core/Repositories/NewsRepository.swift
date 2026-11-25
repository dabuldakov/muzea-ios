import Foundation

/// Реализация `NewsRepository` на основном бэкенде.
final class NewsRepositoryImpl: NewsRepository {
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func getNews(page: Int, size: Int) async throws -> Page<News> {
        let response: PageResponse<NewsDTO> = try await client.request(
            "GET",
            "/api/news",
            query: [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "size", value: "\(size)")
            ]
        )
        return response.toDomain { $0.toDomain() }
    }

    func getNewsById(_ id: Int64) async throws -> News {
        let dto: NewsDTO = try await client.request("GET", "/api/news/\(id)")
        return dto.toDomain()
    }

    func createNews(title: String, content: String, videoId: Int64?, image: UploadFile?) async throws -> NewsCreateResponse {
        var fields = ["title": title, "content": content]
        if let videoId { fields["videoId"] = "\(videoId)" }

        if let image {
            return try await client.upload(
                "/api/news",
                fields: fields,
                files: [
                    MultipartFile(
                        field: "image",
                        fileName: image.fileName,
                        mimeType: image.mimeType,
                        data: image.data
                    )
                ]
            )
        }
        return try await client.uploadForm("/api/news", fields: fields)
    }

    func updateNews(
        id: Int64,
        title: String,
        content: String,
        videoId: Int64?,
        removeVideo: Bool,
        image: UploadFile?,
        removeImage: Bool
    ) async throws -> News {
        var fields = [
            "title": title,
            "content": content,
            "removeVideo": removeVideo ? "true" : "false",
            "removeImage": removeImage ? "true" : "false"
        ]
        if let videoId { fields["videoId"] = "\(videoId)" }

        let dto: NewsDTO
        if let image {
            dto = try await client.upload(
                "/api/news/\(id)",
                method: "PUT",
                fields: fields,
                files: [
                    MultipartFile(
                        field: "image",
                        fileName: image.fileName,
                        mimeType: image.mimeType,
                        data: image.data
                    )
                ]
            )
        } else {
            dto = try await client.uploadForm(
                "/api/news/\(id)",
                method: "PUT",
                fields: fields
            )
        }
        return dto.toDomain()
    }

    func deleteNews(_ id: Int64) async throws {
        try await client.requestVoid("DELETE", "/api/news/\(id)")
    }

    func likeNews(_ id: Int64) async throws -> Int64 {
        let response: NewsLikeResponseDTO = try await client.request(
            "POST",
            "/api/news/\(id)/like"
        )
        return response.likes
    }

    func unlikeNews(_ id: Int64) async throws -> Int64 {
        let response: NewsLikeResponseDTO = try await client.request(
            "DELETE",
            "/api/news/\(id)/like"
        )
        return response.likes
    }

    func likedNewsIds() async throws -> Set<Int64> {
        let response: LikedNewsResponseDTO = try await client.request(
            "GET",
            "/api/news/likes/me"
        )
        return Set(response.likedIds)
    }

    func registerNewsView(_ id: Int64) async {
        try? await client.requestVoid("POST", "/api/news/\(id)/view", authorized: false)
    }

    func getNewsComments(
        _ newsId: Int64,
        before: Int64?,
        size: Int
    ) async throws -> NewsCommentsPage {
        var query = [URLQueryItem(name: "size", value: "\(size)")]
        if let before { query.append(URLQueryItem(name: "before", value: "\(before)")) }
        let response: NewsCommentsResponseDTO = try await client.request(
            "GET",
            "/api/news/\(newsId)/comments",
            query: query
        )
        return response.toDomain()
    }

    func addNewsComment(_ newsId: Int64, content: String) async throws -> NewsComment {
        let dto: NewsCommentDTO = try await client.request(
            "POST",
            "/api/news/\(newsId)/comments",
            body: CreateNewsCommentRequest(content: content)
        )
        return dto.toDomain()
    }

    func deleteNewsComment(_ newsId: Int64, commentId: Int64) async throws {
        try await client.requestVoid(
            "DELETE",
            "/api/news/\(newsId)/comments/\(commentId)"
        )
    }
}
