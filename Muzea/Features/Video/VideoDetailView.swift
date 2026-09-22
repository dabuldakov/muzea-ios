import SwiftUI
import AVKit
import AVFoundation

struct VideoDetailView: View {
    let video: VideoResponse
    var repository: VideoRepository? = nil
    var ownUsername: String? = nil
    var authToken: String? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var isDeleting = false
    @State private var showDeleteConfirm = false
    @State private var error: String?

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

                if let error {
                    Text(error).foregroundColor(.red).font(.footnote)
                }

                if canDelete {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        if isDeleting {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Удалить видео").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isDeleting)
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
        if let authToken, !authToken.isEmpty {
            let asset = AVURLAsset(
                url: url,
                options: ["AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Bearer \(authToken)"]]
            )
            return AVPlayer(playerItem: AVPlayerItem(asset: asset))
        }
        return AVPlayer(url: url)
    }

    private var canDelete: Bool {
        guard repository != nil, let ownUsername, !ownUsername.isEmpty else { return false }
        return video.uploadedBy.trimmingCharacters(in: .whitespaces) == ownUsername.trimmingCharacters(in: .whitespaces)
    }

    private func delete() {
        guard let repository else { return }
        isDeleting = true
        error = nil
        Task {
            do {
                try await repository.deleteVideo(video.id)
                dismiss()
            } catch {
                self.error = error.localizedDescription
                isDeleting = false
            }
        }
    }
}
