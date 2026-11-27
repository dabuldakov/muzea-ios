import SwiftUI

struct NewsDetailView: View {
    let newsId: Int64
    let container: AppContainer

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: NewsDetailViewModel
    @State private var commentText = ""
    @State private var showDeleteConfirm = false
    @State private var showReport = false
    @State private var showEdit = false
    @State private var reportNotice: String?
    @State private var commentToDelete: NewsComment?
    @State private var showCommentDelete = false
    @State private var commentToReport: NewsComment?
    @State private var showCommentReport = false

    init(newsId: Int64, container: AppContainer) {
        self.newsId = newsId
        self.container = container
        _viewModel = StateObject(wrappedValue: NewsDetailViewModel(
            repository: container.newsRepository
        ))
    }

    var body: some View {
        ScrollView {
            if let news = viewModel.news {
                VStack(alignment: .leading, spacing: 12) {
                    if let url = ImageURL.makeup(news.imageUrl) {
                        FullWidthImage(url: url, height: 260, contentMode: .fit)
                    }

                    Text(news.title)
                        .font(.title2).bold()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Text(L10n.newsAuthor(news.author))
                        Spacer()
                        Text(DateTimeFormat.full(news.publishedAt))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        Button {
                            Task { await viewModel.toggleLike() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: news.likedByMe ? "heart.fill" : "heart")
                                    .foregroundColor(.red)
                                Text(CountFormat.short(news.likes))
                            }
                        }
                        .buttonStyle(.plain)

                        Label(CountFormat.short(news.views), systemImage: "eye")
                        Label(CountFormat.short(viewModel.commentsTotal), systemImage: "bubble.right")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    Text(news.content)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let video = news.relatedVideo {
                        NavigationLink(value: Route.videoDetail(video)) {
                            Label(L10n.newsWatch(video.title), systemImage: "play.rectangle")
                        }
                    }

                    if let error = viewModel.error {
                        Text(error).foregroundColor(.red).font(.footnote)
                    }

                    Divider()

                    HStack {
                        Text(L10n.newsCommentsTitle)
                            .font(.headline)
                        Spacer()
                        Text(CountFormat.short(viewModel.commentsTotal))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if viewModel.hasMoreComments {
                        Button {
                            Task { await viewModel.loadOlderComments() }
                        } label: {
                            if viewModel.isLoadingComments {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text(L10n.newsLoadOlder).frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isLoadingComments)
                    }

                    if viewModel.isLoadingComments && viewModel.comments.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 8)
                    } else if viewModel.comments.isEmpty {
                        Text(L10n.newsCommentsEmpty)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    ForEach(viewModel.comments) { comment in
                        commentRow(comment, news: news)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let error = viewModel.error {
                Text(error).foregroundColor(.red).padding()
            } else {
                ProgressView().padding()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.news != nil, canComment {
                composer
            }
        }
        .navigationTitle(L10n.newsDetail)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let news = viewModel.news {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if canEdit(news) {
                            Button {
                                showEdit = true
                            } label: {
                                Label(L10n.edit, systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label(L10n.newsDelete, systemImage: "trash")
                            }
                        } else {
                            Button {
                                showReport = true
                            } label: {
                                Label(L10n.report, systemImage: "exclamationmark.bubble")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .accessibilityLabel(L10n.newsActions)
                    }
                }
            }
        }
        .task { await viewModel.load(id: newsId) }
        .refreshable { await viewModel.reload() }
        .sheet(isPresented: $showEdit) {
            if let news = viewModel.news {
                CreateNewsView(container: container, news: news) {
                    Task { await viewModel.reload() }
                }
            }
        }
        .sheet(isPresented: $showReport) {
            ReportReasonSheet { reason in
                Task { await reportNews(reason: reason) }
            }
        }
        .sheet(isPresented: $showCommentReport) {
            ReportReasonSheet { reason in
                if let comment = commentToReport {
                    Task { await reportComment(comment, reason: reason) }
                }
                commentToReport = nil
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
        .confirmationDialog(
            L10n.newsDeleteTitle,
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.delete, role: .destructive) { deleteNews() }
            Button(L10n.cancel, role: .cancel) {}
        }
        .confirmationDialog(
            L10n.newsDeleteCommentTitle,
            isPresented: $showCommentDelete,
            titleVisibility: .visible
        ) {
            Button(L10n.delete, role: .destructive) {
                if let comment = commentToDelete {
                    Task { await viewModel.deleteComment(comment) }
                }
                commentToDelete = nil
            }
            Button(L10n.cancel, role: .cancel) { commentToDelete = nil }
        }
    }

    private var canComment: Bool {
        !(container.tokenStore.username ?? "").isEmpty
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(L10n.newsCommentHint, text: $commentText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                sendComment()
            } label: {
                if viewModel.isSending {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                }
            }
            .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private func commentRow(_ comment: NewsComment, news: News) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(url: ImageURL.chat(comment.authorAvatarUrl), size: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(comment.author).font(.subheadline).bold()
                    Spacer()
                    Text(DateTimeFormat.full(comment.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(comment.content)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            if canDelete(comment, news: news) {
                Button(role: .destructive) {
                    commentToDelete = comment
                    showCommentDelete = true
                } label: {
                    Label(L10n.delete, systemImage: "trash")
                }
            } else {
                Button {
                    commentToReport = comment
                    showCommentReport = true
                } label: {
                    Label(L10n.report, systemImage: "exclamationmark.bubble")
                }
            }
        }
    }

    private func sendComment() {
        let text = commentText
        Task {
            if await viewModel.addComment(text) {
                commentText = ""
            }
        }
    }

    private func canEdit(_ news: News) -> Bool {
        guard let username = container.tokenStore.username, !username.isEmpty else { return false }
        return news.author == username
    }

    private func canDelete(_ comment: NewsComment, news: News) -> Bool {
        guard let username = container.tokenStore.username, !username.isEmpty else { return false }
        return comment.author == username || news.author == username
    }

    private func deleteNews() {
        Task {
            if await viewModel.delete(id: newsId) {
                dismiss()
            }
        }
    }

    private func reportNews(reason: String) async {
        do {
            try await container.contentReportRepository.report(
                contentType: "NEWS",
                contentId: newsId,
                reason: reason,
                comment: nil
            )
            reportNotice = L10n.reported
        } catch {
            reportNotice = error.localizedDescription
        }
    }

    private func reportComment(_ comment: NewsComment, reason: String) async {
        do {
            try await container.contentReportRepository.report(
                contentType: "NEWS_COMMENT",
                contentId: comment.id,
                reason: reason,
                comment: nil
            )
            reportNotice = L10n.reported
        } catch {
            reportNotice = error.localizedDescription
        }
    }
}
