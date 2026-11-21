import Foundation

@MainActor
final class VideoUploadViewModel: ObservableObject {
    @Published private(set) var isUploading = false
    @Published private(set) var progress = 0
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
        progress = 0
        defer { isUploading = false }
        do {
            error = nil
            _ = try await repository.uploadVideo(
                title: title,
                description: description,
                data: data,
                fileName: fileName,
                mimeType: mimeType,
                thumbnail: thumbnail,
                onProgress: { [weak self] value in
                    Task { @MainActor in
                        self?.progress = min(100, max(0, value))
                    }
                }
            )
            progress = 100
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
