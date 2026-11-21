import SwiftUI
import PhotosUI
import AVFoundation
import UIKit
import UniformTypeIdentifiers

struct VideoUploadView: View {
    let container: AppContainer

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: VideoUploadViewModel
    @State private var title = ""
    @State private var videoDescription = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var videoData: Data?
    @State private var thumbnail: UploadFile?
    @State private var previewImage: UIImage?
    @State private var fileName = "video.mp4"
    @State private var mimeType = "video/mp4"
    @State private var showFilePicker = false
    @State private var selectionError: String?

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: VideoUploadViewModel(repository: container.videoRepository))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.videoDescriptionSection) {
                    TextField(L10n.videoNameField, text: $title)
                    TextField(L10n.videoDescriptionField, text: $videoDescription, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section(L10n.videoFileSection) {
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedItem, matching: .videos) {
                            sourceButton("photo.on.rectangle", L10n.videoPick)
                        }

                        Button {
                            showFilePicker = true
                        } label: {
                            sourceButton("folder", L10n.videoPickFile)
                        }
                        .buttonStyle(.plain)
                    }

                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .cornerRadius(8)
                    }
                }

                if let selectionError {
                    Section { Text(selectionError).foregroundColor(.red) }
                }

                if let error = viewModel.error {
                    Section { Text(error).foregroundColor(.red) }
                }

                Section {
                    Button(action: upload) {
                        if viewModel.isUploading {
                            VStack(spacing: 6) {
                                ProgressView(value: Double(viewModel.progress) / 100)
                                Text("\(viewModel.progress)%")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Text(L10n.videoUpload).frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(title.isEmpty || videoData == nil || viewModel.isUploading)
                }
            }
            .navigationTitle(L10n.videoUploadTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
            .onChange(of: selectedItem) { newValue in
                Task { await loadVideo(newValue) }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    Task { await loadFile(url) }
                }
            }
        }
    }

    private func sourceButton(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Theme.Palette.outgoingStart)
                .frame(width: 64, height: 64)
                .background(Theme.Palette.outgoingStart.opacity(0.08))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Theme.Palette.outgoingStart.opacity(0.2), lineWidth: 1)
                )
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 120)
    }

    private func loadVideo(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            selectionError = L10n.errorVideoRead
            return
        }
        let type = item.supportedContentTypes.first
        let ext = type?.preferredFilenameExtension ?? "mp4"
        let name = "video_\(Int(Date().timeIntervalSince1970)).\(ext)"
        await applyVideo(
            data: data,
            fileName: name,
            mimeType: type?.preferredMIMEType ?? "video/mp4"
        )
    }

    /// Видео из системных «Файлов»: копируем через NSFileCoordinator, чтобы
    /// дождаться скачивания из iCloud/облака, и проверяем целостность атомов.
    private func loadFile(_ url: URL) async {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("upload-\(UUID().uuidString)-\(url.lastPathComponent)")
        defer { try? FileManager.default.removeItem(at: destination) }

        do {
            try await copyFromProvider(url, to: destination)
            let data = try Data(contentsOf: destination)
            let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
                ?? "video/mp4"
            await applyVideo(data: data, fileName: url.lastPathComponent, mimeType: mime)
        } catch {
            selectionError = L10n.errorVideoRead
        }
    }

    private func copyFromProvider(_ source: URL, to destination: URL) async throws {
        var lastSize = 0
        for attempt in 0..<4 {
            try? FileManager.default.removeItem(at: destination)
            var coordinationError: NSError?
            var copyError: Error?
            NSFileCoordinator().coordinate(
                readingItemAt: source,
                options: [.withoutChanges],
                error: &coordinationError
            ) { readableURL in
                do {
                    try FileManager.default.copyItem(at: readableURL, to: destination)
                } catch {
                    copyError = error
                }
            }
            if let coordinationError { throw coordinationError }
            if let copyError { throw copyError }

            let size = (try? destination.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            if size > 0, size == lastSize { return }
            lastSize = size
            if attempt < 3 {
                try? await Task.sleep(nanoseconds: UInt64(0.4 * Double(attempt + 1) * 1_000_000_000))
            }
        }
        if (try? destination.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0 > 0 {
            return
        }
        throw CocoaError(.fileReadUnknown)
    }

    private func applyVideo(data: Data, fileName: String, mimeType: String) async {
        guard !VideoFileValidator.isTruncated(data) else {
            selectionError = L10n.videoCorrupted
            videoData = nil
            previewImage = nil
            return
        }
        selectionError = nil
        videoData = data
        self.fileName = fileName
        self.mimeType = mimeType
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
        Task {
            let success = await viewModel.upload(
                title: title,
                description: videoDescription.isEmpty ? nil : videoDescription,
                data: data,
                fileName: fileName,
                mimeType: mimeType,
                thumbnail: thumbnail
            )
            if success {
                dismiss()
            }
        }
    }
}
