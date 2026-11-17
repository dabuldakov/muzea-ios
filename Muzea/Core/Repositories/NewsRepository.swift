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

    func deleteNews(_ id: Int64) async throws {
        try await client.requestVoid("DELETE", "/api/news/\(id)")
    }
}
