import SwiftUI

struct VideoListView: View {
    @EnvironmentObject private var container: AppContainer
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
                .navigationTitle("Видео")
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
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.state.videos.isEmpty {
            if viewModel.state.isLoading {
                ProgressView()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle").font(.largeTitle).foregroundColor(.secondary)
                    Text(viewModel.state.error ?? "Нет видео").foregroundColor(.secondary)
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
    let video: VideoResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: video.fullThumbnailURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Color.gray.opacity(0.15)
                }
            }
            .frame(height: 120)
            .clipped()
            .cornerRadius(8)

            Text(video.title).font(.subheadline).lineLimit(2)
            Text("\(video.views) просмотров").font(.caption).foregroundColor(.secondary)
        }
    }
}
