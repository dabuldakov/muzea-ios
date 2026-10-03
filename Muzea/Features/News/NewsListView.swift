import SwiftUI

struct NewsListView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: NewsListViewModel
    @StateObject private var router = Router()
    @State private var showCreate = false

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: NewsListViewModel(
            newsRepository: container.newsRepository,
            contactRepository: container.contactRepository,
            ownUsername: container.tokenStore.username
        ))
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            content
                .navigationTitle("Новости")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showCreate = true } label: { Image(systemName: "plus") }
                    }
                }
                .refreshable { await viewModel.load() }
                .navigationDestination(for: Route.self) { RouteDestinationView(route: $0) }
                .sheet(isPresented: $showCreate) {
                    CreateNewsView(container: container)
                }
        }
        .environmentObject(router)
        .task {
            if viewModel.state.news.isEmpty { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.state.news.isEmpty {
            if viewModel.state.isLoading {
                ProgressView()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "newspaper").font(.largeTitle).foregroundColor(.secondary)
                    Text(viewModel.state.error ?? "Нет новостей").foregroundColor(.secondary)
                }
            }
        } else {
            List(viewModel.state.news) { item in
                NavigationLink(value: Route.newsDetail(item.id)) {
                    NewsRow(item: item)
                }
                .task { await viewModel.loadMoreIfNeeded(currentItem: item) }
            }
            .listStyle(.plain)
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
                HStack {
                    Text(item.author).font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(DateTimeFormat.date(item.publishedAt)).font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }
}
