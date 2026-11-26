import AVFoundation
import SwiftUI

struct VideoDetailView: View {
    let video: Video
    let container: AppContainer

    @ObservedObject private var playback: VideoPlaybackManager
    @StateObject private var viewModel: VideoDetailViewModel
    @State private var showActions = false
    @State private var pendingAction: VideoAction?
    @State private var showDeleteConfirm = false
    @State private var showReport = false
    @State private var reportNotice: String?

    init(video: Video, container: AppContainer) {
        self.video = video
        self.container = container
        _playback = ObservedObject(wrappedValue: container.videoPlaybackManager)
        _viewModel = StateObject(wrappedValue: VideoDetailViewModel(repository: container.videoRepository))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VideoPlayerSurface(
                    player: playback.player,
                    gravity: .resizeAspect,
                    playback: playback
                )
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .clipped()
                .cornerRadius(8)
                .overlay(alignment: .bottomTrailing) {
                    if playback.isPictureInPictureSupported {
                        Button {
                            playback.startPictureInPicture()
                        } label: {
                            Image(systemName: "pip.enter")
                                .font(.body)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(8)
                        .accessibilityLabel(L10n.videoPip)
                    }
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

                if let error = viewModel.error ?? playback.error {
                    Text(error).foregroundColor(.red).font(.footnote)
                }
            }
            .padding()
        }
        .navigationTitle(L10n.videoTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showActions = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(L10n.videoActions)
            }
        }
        .sheet(isPresented: $showActions, onDismiss: handlePendingAction) {
            VideoActionsSheet(canDelete: canDelete) { action in
                pendingAction = action
                showActions = false
            }
        }
        .confirmationDialog(
            L10n.videoDeleteTitle,
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
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
        .onAppear {
            playback.setDetailVisible(true)
            playback.play(video)
        }
        .onDisappear {
            // Не останавливаем видео: после возврата его покажет mini-плеер.
            playback.setDetailVisible(false)
        }
    }

    private func handlePendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .delete:
            showDeleteConfirm = true
        case .report:
            showReport = true
        }
    }

    private var canDelete: Bool {
        guard let ownUsername = container.tokenStore.username, !ownUsername.isEmpty else { return false }
        return video.uploadedBy.trimmingCharacters(in: .whitespaces)
            == ownUsername.trimmingCharacters(in: .whitespaces)
    }

    private func delete() {
        Task {
            if await viewModel.delete(id: video.id) {
                playback.close()
                dismiss()
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

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
