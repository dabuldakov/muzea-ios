import SwiftUI

/// Нижняя панель «Эмодзи + GIF»: эмодзи вставляются в текст, GIF отправляются
/// сообщением. Вкладки GIF: «Мои», «Этот чат» и поиск Klipy.
struct EmojiGifSheet: View {
    let repository: GifRepository
    let chatUuid: String
    let onEmoji: (String) -> Void
    let onGif: (Gif) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: GifSearchViewModel
    @State private var mode = 0
    @State private var searchTask: Task<Void, Never>?

    private let emojis = [
        "😀", "😃", "😄", "😁", "😆", "😅", "😂", "🙂",
        "😉", "😊", "😍", "🥰", "😘", "😎", "🤔", "😐",
        "😴", "😢", "😭", "😡", "🤯", "🥳", "👍", "👎",
        "👏", "🙏", "🤝", "💪", "❤️", "💔", "🔥", "✨",
        "🎉", "🎂", "☀️", "🌙", "⭐️", "⚡", "💯", "✅",
        "❌", "👀", "🤡", "💩", "🙈", "🙉", "🙊", "🤗"
    ]

    init(
        repository: GifRepository,
        chatUuid: String,
        onEmoji: @escaping (String) -> Void,
        onGif: @escaping (Gif) -> Void
    ) {
        self.repository = repository
        self.chatUuid = chatUuid
        self.onEmoji = onEmoji
        self.onGif = onGif
        _viewModel = StateObject(wrappedValue: GifSearchViewModel(
            repository: repository,
            chatUuid: chatUuid
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(L10n.mode, selection: $mode) {
                    Text(L10n.emoji).tag(0)
                    Text("GIF").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(12)

                if mode == 0 {
                    emojiGrid
                } else {
                    gifContent
                }
            }
            .navigationTitle(L10n.emojiGif)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onChange(of: mode) { value in
            if value == 1 {
                Task { await viewModel.loadIfNeeded() }
            }
        }
        .onChange(of: viewModel.query) { value in
            guard viewModel.tab == .search else { return }
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                await viewModel.search(query: value)
            }
        }
    }

    private var emojiGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8),
                spacing: 10
            ) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(emoji) {
                        onEmoji(emoji)
                    }
                    .font(.title2)
                }
            }
            .padding(12)
        }
    }

    private var gifContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(GifTab.allCases) { tab in
                    Button {
                        Task { await viewModel.select(tab) }
                    } label: {
                        Text(tab.title)
                            .font(.caption).bold()
                            .foregroundColor(viewModel.tab == tab ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                viewModel.tab == tab
                                    ? Color.accentColor
                                    : Color(.secondarySystemBackground)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            if viewModel.tab == .search {
                if Config.klipyAppKey.trimmingCharacters(in: .whitespaces).isEmpty {
                    message(L10n.gifsUnavailable)
                } else {
                    TextField(L10n.gifsSearchPlaceholder, text: $viewModel.query)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
            }

            if viewModel.isLoading && viewModel.gifs.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.gifs.isEmpty {
                message(L10n.gifsEmpty)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 8
                    ) {
                        ForEach(viewModel.gifs) { gif in
                            Button {
                                onGif(gif)
                                dismiss()
                            } label: {
                                AsyncImage(url: URL(string: gif.previewUrl ?? gif.url)) { phase in
                                    if case .success(let image) = phase {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Color(.tertiarySystemBackground)
                                    }
                                }
                                .frame(height: 110)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)

                    if viewModel.hasMore {
                        Button(L10n.gifsLoadMore) {
                            Task { await viewModel.loadNextPage() }
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .task { await viewModel.loadIfNeeded() }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
