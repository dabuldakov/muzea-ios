import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

struct VideoUploadView: View {
    let videoRepository: VideoRepository
    let ownUsername: String?

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var videoDescription = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var videoData: Data?
    @State private var thumbnail: UploadFile?
    @State private var previewImage: UIImage?
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

                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .clipped()
                            .cornerRadius(8)
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
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        videoData = data
        fileName = "video_\(Int(Date().timeIntervalSince1970)).mp4"
        await makeThumbnail(from: data)
    }

    /// Извлекает кадр из видео для превью и загрузки на сервер (как Android MediaMetadataRetriever).
    private func makeThumbnail(from data: Data) async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("thumb_src_\(UUID().uuidString).mp4")
        guard (try? data.write(to: url)) != nil else { return }
        defer { try? FileManager.default.removeItem(at: url) }

        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1, preferredTimescale: 600)

        guard let result = try? await generator.image(at: time) else {
            thumbnail = nil
            previewImage = nil
            return
        }
        let cgImage = result.image
        let image = UIImage(cgImage: cgImage)
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
        previewImage = image
        thumbnail = UploadFile(data: jpeg, fileName: "thumbnail.jpeg", mimeType: "image/jpeg")
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
                    mimeType: "video/mp4",
                    thumbnail: thumbnail
                )
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isUploading = false
        }
    }
}
