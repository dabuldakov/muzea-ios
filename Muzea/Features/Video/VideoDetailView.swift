import SwiftUI
import AVKit
import AVFoundation

struct VideoDetailView: View {
    let video: VideoResponse
    let container: AppContainer

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: VideoDetailViewModel
    @State private var player: AVPlayer?
    @State private var showDeleteConfirm = false

    init(video: VideoResponse, container: AppContainer) {
        self.video = video
        self.container = container
        _viewModel = StateObject(wrappedValue: VideoDetailViewModel(repository: container.videoRepository))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let player {
                    VideoPlayer(player: player)
                        .frame(height: 220)
                        .cornerRadius(8)
                }

                Text(video.title).font(.title3).bold()

                if let description = video.description, !description.isEmpty {
                    Text(description)
                }

                HStack {
                    Text("Автор: \(video.uploadedBy)")
                    Spacer()
                    Text("\(video.views) просмотров")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                HStack {
                    Text("\(video.likes ?? 0) лайков")
                    Spacer()
                    if !video.uploadedAt.isEmpty {
                        Text(DateTimeFormat.full(video.uploadedAt))
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)

                if let error = viewModel.error {
                    Text(error).foregroundColor(.red).font(.footnote)
                }

                if canDelete {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        if viewModel.isDeleting {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Удалить видео").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isDeleting)
                }
            }
            .padding()
        }
        .navigationTitle("Видео")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Удалить видео?", isPresented: $showDeleteConfirm) {
            Button("Удалить", role: .destructive) { delete() }
            Button("Отмена", role: .cancel) {}
        }
        .onAppear { if player == nil { player = makePlayer() } }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func makePlayer() -> AVPlayer? {
        guard let url = video.fullVideoURL else { return nil }
        if let authToken = container.tokenStore.token, !authToken.isEmpty {
            let asset = AVURLAsset(
                url: url,
                options: ["AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Bearer \(authToken)"]]
            )
            return AVPlayer(playerItem: AVPlayerItem(asset: asset))
        }
        return AVPlayer(url: url)
    }

    private var canDelete: Bool {
        guard let ownUsername = container.tokenStore.username, !ownUsername.isEmpty else { return false }
        return video.uploadedBy.trimmingCharacters(in: .whitespaces)
            == ownUsername.trimmingCharacters(in: .whitespaces)
    }

    private func delete() {
        Task {
            if await viewModel.delete(id: video.id) {
                dismiss()
            }
        }
    }
}
