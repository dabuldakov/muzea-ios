import Foundation

@MainActor
final class VideoUploadViewModel: ObservableObject {
    @Published private(set) var isUploading = false
    @Published private(set) var error: String?

    private let repository: VideoRepository

    init(repository: VideoRepository) {
        self.repository = repository
    }

    func upload(
        title: String,
        description: String?,
        data: Data,
        fileName: String,
        mimeType: String,
        thumbnail: UploadFile?
    ) async -> Bool {
        isUploading = true
        defer { isUploading = false }
        do {
            error = nil
            _ = try await repository.uploadVideo(
                title: title,
                description: description,
                data: data,
                fileName: fileName,
                mimeType: mimeType,
                thumbnail: thumbnail
            )
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
