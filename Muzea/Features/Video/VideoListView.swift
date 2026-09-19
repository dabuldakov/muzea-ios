import SwiftUI

struct VideoListView: View {
    @StateObject private var viewModel: VideoListViewModel
    @State private var showUpload = false

    private let videoRepository: VideoRepository
    private let ownUsername: String?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: VideoListViewModel(
            repository: container.videoRepository,
            ownUsername: container.tokenStore.username
        ))
        videoRepository = container.videoRepository
        ownUsername = container.tokenStore.username
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.videos.isEmpty {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "play.rectangle").font(.largeTitle).foregroundColor(.secondary)
                            Text(viewModel.error ?? "Нет видео").foregroundColor(.secondary)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(viewModel.videos) { video in
                                NavigationLink {
                                    VideoDetailView(video: video)
                                } label: {
                                    VideoCell(video: video)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Видео")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showUpload = true } label: { Image(systemName: "plus") }
                }
            }
            .refreshable { await viewModel.load() }
            .sheet(isPresented: $showUpload) {
                VideoUploadView(videoRepository: videoRepository, ownUsername: ownUsername)
            }
        }
        .task {
            if viewModel.videos.isEmpty { await viewModel.load() }
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
