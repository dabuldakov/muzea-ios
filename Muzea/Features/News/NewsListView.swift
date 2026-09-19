import SwiftUI

struct NewsListView: View {
    @StateObject private var viewModel: NewsListViewModel
    @State private var showCreate = false

    private let newsRepository: NewsRepository
    private let videoRepository: VideoRepository
    private let ownUsername: String?

    init(container: AppContainer) {
        let store = container.tokenStore
        _viewModel = StateObject(wrappedValue: NewsListViewModel(
            newsRepository: container.newsRepository,
            chatRepository: container.chatRepository,
            ownUsername: store.username
        ))
        newsRepository = container.newsRepository
        videoRepository = container.videoRepository
        ownUsername = store.username
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.news.isEmpty {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "newspaper").font(.largeTitle).foregroundColor(.secondary)
                            Text(viewModel.error ?? "Нет новостей").foregroundColor(.secondary)
                        }
                    }
                } else {
                    List(viewModel.news) { item in
                        NavigationLink(value: item) {
                            NewsRow(item: item)
                        }
                        .task { await viewModel.loadMoreIfNeeded(currentItem: item) }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Новости")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showCreate = true } label: { Image(systemName: "plus") }
                }
            }
            .refreshable { await viewModel.load() }
            .navigationDestination(for: NewsResponse.self) { item in
                NewsDetailView(
                    newsId: item.id,
                    newsRepository: newsRepository,
                    ownUsername: ownUsername
                )
            }
            .sheet(isPresented: $showCreate) {
                CreateNewsView(
                    newsRepository: newsRepository,
                    videoRepository: videoRepository,
                    ownUsername: ownUsername
                )
            }
        }
        .task {
            if viewModel.news.isEmpty { await viewModel.load() }
        }
    }
}

struct NewsRow: View {
    let item: NewsResponse

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: ImageURL.makeup(item.imageUrl)) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Color.gray.opacity(0.15)
                }
            }
            .frame(width: 72, height: 72)
            .clipped()
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline).lineLimit(2)
                Text(item.author).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}
