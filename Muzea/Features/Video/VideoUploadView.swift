import SwiftUI
import PhotosUI

struct VideoUploadView: View {
    let videoRepository: VideoRepository
    let ownUsername: String?

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var videoDescription = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var videoData: Data?
    @State private var fileName = "video.mp4"
    @State private var isUploading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Описание") {
                    TextField("Название", text: $title)
                    TextField("Описание", text: $videoDescription, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Файл") {
                    PhotosPicker(selection: $selectedItem, matching: .videos) {
                        Label(
                            videoData == nil ? "Выбрать видео" : "Видео выбрано",
                            systemImage: "film"
                        )
                    }
                }

                if let error {
                    Section { Text(error).foregroundColor(.red) }
                }

                Section {
                    Button(action: upload) {
                        if isUploading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Загрузить").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(title.isEmpty || videoData == nil || isUploading)
                }
            }
            .navigationTitle("Загрузка видео")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .onChange(of: selectedItem) { newValue in
                Task { await loadVideo(newValue) }
            }
        }
    }

    private func loadVideo(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            videoData = data
            fileName = "video_\(Int(Date().timeIntervalSince1970)).mp4"
        }
    }

    private func upload() {
        guard let data = videoData else { return }
        isUploading = true
        error = nil
        Task {
            do {
                _ = try await videoRepository.uploadVideo(
                    title: title,
                    description: videoDescription.isEmpty ? nil : videoDescription,
                    data: data,
                    fileName: fileName,
                    mimeType: "video/mp4"
                )
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isUploading = false
        }
    }
}
