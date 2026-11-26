import SwiftUI

struct VideoListView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var appRouter: AppRouter
    @StateObject private var viewModel: VideoListViewModel
    @StateObject private var router = Router()
    @State private var showUpload = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: VideoListViewModel(
            repository: container.videoRepository,
            ownUsername: container.tokenStore.username
        ))
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            content
                .navigationTitle(L10n.videoTitle)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showUpload = true } label: { Image(systemName: "plus") }
                    }
                }
                .refreshable { await viewModel.load() }
                .navigationDestination(for: Route.self) { RouteDestinationView(route: $0) }
                .sheet(isPresented: $showUpload) {
                    VideoUploadView(container: container)
                }
        }
        .environmentObject(router)
        .task {
            if viewModel.state.videos.isEmpty { await viewModel.load() }
        }
        .onAppear { openPendingVideo() }
        .onChange(of: appRouter.videoTarget) { _ in openPendingVideo() }
    }

    private func openPendingVideo() {
        guard let video = appRouter.consumeVideoTarget() else { return }
        router.push(.videoDetail(video))
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.state.videos.isEmpty {
            if viewModel.state.isLoading {
                ProgressView()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle").font(.largeTitle).foregroundColor(.secondary)
                    Text(viewModel.state.error ?? L10n.videoEmpty).foregroundColor(.secondary)
                }
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.state.videos) { video in
                        NavigationLink(value: Route.videoDetail(video)) {
                            VideoCell(video: video)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }
}

struct VideoCell: View {
    let video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FullWidthImage(
                url: video.fullThumbnailURL,
                height: 120,
                placeholderIcon: "play.rectangle"
            )
            .cornerRadius(8)

            Text(video.title).font(.subheadline).lineLimit(2)
            Text(L10n.videoViews(video.views)).font(.caption).foregroundColor(.secondary)
        }
    }
}
