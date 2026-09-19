import Foundation

final class VideoRepository {
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func getVideos() async throws -> [VideoResponse] {
        try await client.request("GET", "/api/videos")
    }

    func getVideoById(_ id: Int64) async throws -> VideoResponse {
        try await client.request("GET", "/api/videos/\(id)")
    }

    func uploadVideo(
        title: String,
        description: String?,
        data: Data,
        fileName: String,
        mimeType: String
    ) async throws -> VideoResponse {
        var fields = ["title": title]
        if let description, !description.isEmpty { fields["description"] = description }
        return try await client.upload(
            "/api/videos/upload",
            fields: fields,
            fileField: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: data
        )
    }
}
