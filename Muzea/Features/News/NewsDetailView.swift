import SwiftUI

struct NewsDetailView: View {
    let newsId: Int64
    let container: AppContainer

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: NewsDetailViewModel
    @State private var showDeleteConfirm = false
    @State private var showReport = false
    @State private var reportNotice: String?

    init(newsId: Int64, container: AppContainer) {
        self.newsId = newsId
        self.container = container
        _viewModel = StateObject(wrappedValue: NewsDetailViewModel(repository: container.newsRepository))
    }

    var body: some View {
        ScrollView {
            if let news = viewModel.news {
                VStack(alignment: .leading, spacing: 12) {
                    if let url = ImageURL.makeup(news.imageUrl) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            } else {
                                Color.gray.opacity(0.15)
                            }
                        }
                        .frame(height: 240)
                        .clipped()
                    }

                    Text(news.title).font(.title2).bold()

                    HStack {
                        Text("Автор: \(news.author)")
                        Spacer()
                        Text(DateTimeFormat.full(news.publishedAt))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Text(news.content)

                    if let video = news.relatedVideo {
                        NavigationLink(value: Route.videoDetail(video)) {
                            Label("Смотреть: \(video.title)", systemImage: "play.rectangle")
                        }
                    }

                    if let error = viewModel.error {
                        Text(error).foregroundColor(.red).font(.footnote)
                    }

                    if canDelete(news) {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            if viewModel.isDeleting {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text("Удалить новость").frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(viewModel.isDeleting)
                    }
                }
                .padding()
            } else if let error = viewModel.error {
                Text(error).foregroundColor(.red).padding()
            } else {
                ProgressView().padding()
            }
        }
        .navigationTitle("Новость")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let news = viewModel.news, !canDelete(news) {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showReport = true
                    } label: {
                        Image(systemName: "exclamationmark.bubble")
                    }
                }
            }
        }
        .task { await viewModel.load(id: newsId) }
        .sheet(isPresented: $showReport) {
            ReportReasonSheet { reason in
                Task { await report(reason: reason) }
            }
        }
        .alert("Жалоба", isPresented: Binding(
            get: { reportNotice != nil },
            set: { if !$0 { reportNotice = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reportNotice ?? "")
        }
        .confirmationDialog("Удалить новость?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) { delete() }
            Button("Отмена", role: .cancel) {}
        }
    }

    private func canDelete(_ news: News) -> Bool {
        guard let ownUsername = container.tokenStore.username, !ownUsername.isEmpty else { return false }
        return news.author == ownUsername
    }

    private func delete() {
        Task {
            if await viewModel.delete(id: newsId) {
                dismiss()
            }
        }
    }

    private func report(reason: String) async {
        do {
            try await container.contentReportRepository.report(
                contentType: "NEWS",
                contentId: newsId,
                reason: reason,
                comment: nil
            )
            reportNotice = "Жалоба отправлена"
        } catch {
            reportNotice = error.localizedDescription
        }
    }
}
