import SwiftUI

struct NewsListView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var appRouter: AppRouter
    @StateObject private var viewModel: NewsListViewModel
    @StateObject private var router = Router()
    @State private var showCreate = false

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: NewsListViewModel(
            newsRepository: container.newsRepository,
            contactRepository: container.contactRepository,
            ownUsername: container.tokenStore.username,
            likeStore: container.newsLikeStore
        ))
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            content
                .navigationTitle(L10n.newsTitle)
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
        .onAppear { openPendingNews() }
        .onChange(of: appRouter.newsTarget) { _ in openPendingNews() }
    }

    private func openPendingNews() {
        guard let id = appRouter.consumeNewsTarget() else { return }
        router.push(.newsDetail(id))
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.state.news.isEmpty {
            if viewModel.state.isLoading {
                ProgressView()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "newspaper").font(.largeTitle).foregroundColor(.secondary)
                    Text(viewModel.state.error ?? L10n.newsEmpty).foregroundColor(.secondary)
                }
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.state.news) { item in
                        NewsRow(item: item) {
                            Task { await viewModel.toggleLike(item.id) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { router.push(.newsDetail(item.id)) }
                        .task { await viewModel.loadMoreIfNeeded(currentItem: item) }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct NewsRow: View {
    let item: News
    let onLike: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FullWidthImage(
                url: ImageURL.makeup(item.imageUrl),
                height: 180,
                contentMode: .fit
            )

            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(.system(size: 17, weight: .semibold))
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !item.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.content)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                        .lineLimit(2)
                        .padding(.top, 6)
                }

                HStack {
                    Text(item.author)
                    Spacer(minLength: 8)
                    Text(DateTimeFormat.date(item.publishedAt))
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.top, 12)

                HStack(spacing: 14) {
                    Button(action: onLike) {
                        HStack(spacing: 4) {
                            Image(systemName: item.likedByMe ? "heart.fill" : "heart")
                                .foregroundColor(.red)
                            Text(CountFormat.short(item.likes))
                        }
                    }
                    .buttonStyle(.plain)

                    Label(CountFormat.short(item.views), systemImage: "eye")
                    Label(CountFormat.short(item.commentsCount), systemImage: "bubble.right")
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.top, 8)
            }
            .padding(16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
