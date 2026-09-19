import SwiftUI

struct NewsDetailView: View {
    let newsId: Int64
    let newsRepository: NewsRepository
    let ownUsername: String?

    @Environment(\.dismiss) private var dismiss
    @State private var news: NewsResponse?
    @State private var error: String?
    @State private var isDeleting = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            if let news {
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
                        Text(news.publishedAt)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Text(news.content)

                    if let video = news.relatedVideo {
                        NavigationLink {
                            VideoDetailView(video: video)
                        } label: {
                            Label("Смотреть: \(video.title)", systemImage: "play.rectangle")
                        }
                    }

                    if canDelete(news) {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            if isDeleting {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text("Удалить новость").frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(isDeleting)
                    }
                }
                .padding()
            } else if let error {
                Text(error).foregroundColor(.red).padding()
            } else {
                ProgressView().padding()
            }
        }
        .navigationTitle("Новость")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Удалить новость?", isPresented: $showDeleteConfirm) {
            Button("Удалить", role: .destructive) { delete() }
            Button("Отмена", role: .cancel) {}
        }
    }

    private func canDelete(_ news: NewsResponse) -> Bool {
        guard let ownUsername, !ownUsername.isEmpty else { return false }
        return news.author == ownUsername
    }

    private func load() async {
        do {
            news = try await newsRepository.getNewsById(newsId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete() {
        isDeleting = true
        Task {
            do {
                try await newsRepository.deleteNews(newsId)
                dismiss()
            } catch {
                self.error = error.localizedDescription
                isDeleting = false
            }
        }
    }
}
