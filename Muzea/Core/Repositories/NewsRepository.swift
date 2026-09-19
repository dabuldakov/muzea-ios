import Foundation

struct UploadFile {
    let data: Data
    let fileName: String
    let mimeType: String
}

final class NewsRepository {
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func getNews(page: Int, size: Int) async throws -> PageResponse<NewsResponse> {
        try await client.request(
            "GET",
            "/api/news",
            query: [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "size", value: "\(size)")
            ]
        )
    }

    func getNewsById(_ id: Int64) async throws -> NewsResponse {
        try await client.request("GET", "/api/news/\(id)")
    }

    func createNews(title: String, content: String, videoId: Int64?, image: UploadFile?) async throws -> NewsCreateResponse {
        var fields = ["title": title, "content": content]
        if let videoId { fields["videoId"] = "\(videoId)" }

        if let image {
            return try await client.upload(
                "/api/news",
                fields: fields,
                fileField: "image",
                fileName: image.fileName,
                mimeType: image.mimeType,
                fileData: image.data
            )
        }
        return try await client.uploadForm("/api/news", fields: fields)
    }

    func deleteNews(_ id: Int64) async throws {
        try await client.requestVoid("DELETE", "/api/news/\(id)")
    }
}
