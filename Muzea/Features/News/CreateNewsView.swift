import SwiftUI
import PhotosUI

struct CreateNewsView: View {
    let newsRepository: NewsRepository
    let videoRepository: VideoRepository
    let ownUsername: String?

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var imageName = "image.jpg"
    @State private var ownVideos: [VideoResponse] = []
    @State private var selectedVideoId: Int64?
    @State private var isSubmitting = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Новость") {
                    TextField("Заголовок", text: $title)
                    TextField("Текст", text: $content, axis: .vertical)
                        .lineLimit(4...12)
                }

                Section("Изображение") {
                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        Label(
                            imageData == nil ? "Выбрать изображение" : "Изображение выбрано",
                            systemImage: "photo"
                        )
                    }
                }

                if !ownVideos.isEmpty {
                    Section("Видео") {
                        Picker("Видео", selection: $selectedVideoId) {
                            Text("Нет").tag(Int64?.none)
                            ForEach(ownVideos) { video in
                                Text(video.title).tag(Int64?.some(video.id))
                            }
                        }
                    }
                }

                if let error {
                    Section { Text(error).foregroundColor(.red) }
                }

                Section {
                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Опубликовать").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(title.isEmpty || content.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("Новая новость")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .task { await loadVideos() }
            .onChange(of: selectedImage) { newValue in
                Task { await loadImage(newValue) }
            }
        }
    }

    private func loadVideos() async {
        guard let ownUsername else { return }
        ownVideos = ((try? await videoRepository.getVideos()) ?? [])
            .filter { $0.uploadedBy == ownUsername }
    }

    private func loadImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            imageData = data
            imageName = "news_\(Int(Date().timeIntervalSince1970)).jpg"
        }
    }

    private func submit() {
        isSubmitting = true
        error = nil
        Task {
            do {
                let image = imageData.map {
                    UploadFile(data: $0, fileName: imageName, mimeType: "image/jpeg")
                }
                _ = try await newsRepository.createNews(
                    title: title,
                    content: content,
                    videoId: selectedVideoId,
                    image: image
                )
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
