import SwiftUI
import PhotosUI

struct CreateNewsView: View {
    let container: AppContainer

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreateNewsViewModel
    @State private var title = ""
    @State private var content = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var imageName = "image.jpg"
    @State private var selectedVideoId: Int64?

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: CreateNewsViewModel(
            newsRepository: container.newsRepository,
            videoRepository: container.videoRepository
        ))
    }

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

                if !viewModel.ownVideos.isEmpty {
                    Section("Видео") {
                        Picker("Видео", selection: $selectedVideoId) {
                            Text("Нет").tag(Int64?.none)
                            ForEach(viewModel.ownVideos) { video in
                                Text(video.title).tag(Int64?.some(video.id))
                            }
                        }
                    }
                }

                if let error = viewModel.error {
                    Section { Text(error).foregroundColor(.red) }
                }

                Section {
                    Button(action: submit) {
                        if viewModel.isSubmitting {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Опубликовать").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(title.isEmpty || content.isEmpty || viewModel.isSubmitting)
                }
            }
            .navigationTitle("Новая новость")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .task { await viewModel.loadVideos(ownUsername: container.tokenStore.username) }
            .onChange(of: selectedImage) { newValue in
                Task { await loadImage(newValue) }
            }
        }
    }

    private func loadImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            imageData = data
            imageName = "news_\(Int(Date().timeIntervalSince1970)).jpg"
        }
    }

    private func submit() {
        Task {
            let image = imageData.map {
                UploadFile(data: $0, fileName: imageName, mimeType: "image/jpeg")
            }
            let success = await viewModel.submit(
                title: title,
                content: content,
                videoId: selectedVideoId,
                image: image
            )
            if success {
                dismiss()
            }
        }
    }
}
