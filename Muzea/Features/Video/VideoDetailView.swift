import SwiftUI
import AVKit
import AVFoundation

struct VideoDetailView: View {
    let video: Video
    let container: AppContainer

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: VideoDetailViewModel
    @State private var player: AVPlayer?
    @State private var showDeleteConfirm = false
    @State private var showReport = false
    @State private var reportNotice: String?

    init(video: Video, container: AppContainer) {
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
                    Text(L10n.videoAuthor(video.uploadedBy))
                    Spacer()
                    Text(L10n.videoViews(video.views))
                }
                .font(.caption)
                .foregroundColor(.secondary)

                HStack {
                    Text(L10n.videoLikes(video.likes ?? 0))
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
                            Text(L10n.videoDelete).frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isDeleting)
                }
            }
            .padding()
        }
        .navigationTitle(L10n.videoTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !canDelete {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showReport = true
                    } label: {
                        Image(systemName: "exclamationmark.bubble")
                    }
                }
            }
        }
        .confirmationDialog(L10n.videoDeleteTitle, isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(L10n.delete, role: .destructive) { delete() }
            Button(L10n.cancel, role: .cancel) {}
        }
        .sheet(isPresented: $showReport) {
            ReportReasonSheet { reason in
                Task { await report(reason: reason) }
            }
        }
        .alert(L10n.reportAlert, isPresented: Binding(
            get: { reportNotice != nil },
            set: { if !$0 { reportNotice = nil } }
        )) {
            Button(L10n.done, role: .cancel) {}
        } message: {
            Text(reportNotice ?? "")
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

    private func report(reason: String) async {
        do {
            try await container.contentReportRepository.report(
                contentType: "VIDEO",
                contentId: video.id,
                reason: reason,
                comment: nil
            )
            reportNotice = L10n.reported
        } catch {
            reportNotice = error.localizedDescription
        }
    }
}
