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
        mimeType: String,
        thumbnail: UploadFile? = nil
    ) async throws -> VideoResponse {
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
        return try await client.upload(
            "/api/videos/upload",
            fields: fields,
            files: files
        )
    }

    func deleteVideo(_ id: Int64) async throws {
        try await client.requestVoid("DELETE", "/api/videos/\(id)")
    }
}
