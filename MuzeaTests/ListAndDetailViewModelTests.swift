import XCTest
@testable import Muzea

@MainActor
final class ChatListViewModelTests: XCTestCase {

    func testStartsWithCachedChats() {
        let repository = FakeChatRepository()
        repository.cached = [TestData.chat("c-1")]

        let viewModel = ChatListViewModel(repository: repository)

        XCTAssertEqual(viewModel.state.chats.map(\.chatUuid), ["c-1"])
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertEqual(viewModel.state.viewState, .list)
    }

    func testLoadReplacesCacheWithServerList() async {
        let repository = FakeChatRepository()
        repository.cached = [TestData.chat("c-old")]
        repository.chats = [TestData.chat("c-1"), TestData.chat("c-2", unread: 3)]
        let viewModel = ChatListViewModel(repository: repository)

        await viewModel.load()

        XCTAssertEqual(viewModel.state.chats.map(\.chatUuid), ["c-1", "c-2"])
        XCTAssertNil(viewModel.state.error)
        XCTAssertFalse(viewModel.state.isLoading)
    }

    func testLoadErrorWithoutCacheIsShown() async {
        let repository = FakeChatRepository()
        repository.loadChatsError = APIError.server(500, "boom")
        let viewModel = ChatListViewModel(repository: repository)

        await viewModel.load()

        XCTAssertEqual(viewModel.state.viewState, .error)
        XCTAssertNotNil(viewModel.state.error)
    }

    func testLoadErrorWithCacheKeepsListAndPrefixesError() async {
        let repository = FakeChatRepository()
        repository.cached = [TestData.chat("c-1")]
        repository.loadChatsError = APIError.server(500, "boom")
        let viewModel = ChatListViewModel(repository: repository)

        await viewModel.load()

        XCTAssertEqual(viewModel.state.chats.map(\.chatUuid), ["c-1"])
        XCTAssertEqual(viewModel.state.viewState, .list)
        XCTAssertEqual(
            viewModel.state.error,
            L10n.errorDetails(APIError.server(500, "boom").localizedDescription)
        )
    }

    func testConsumeErrorClearsMessage() async {
        let repository = FakeChatRepository()
        repository.loadChatsError = APIError.server(500, "boom")
        let viewModel = ChatListViewModel(repository: repository)
        await viewModel.load()

        viewModel.consumeError()

        XCTAssertNil(viewModel.state.error)
    }

    func testViewStateDerivation() {
        XCTAssertEqual(ChatListUiState().viewState, .empty)
        XCTAssertEqual(ChatListUiState(isLoading: true).viewState, .loading)
        XCTAssertEqual(ChatListUiState(error: "x").viewState, .error)
        XCTAssertEqual(
            ChatListUiState(chats: [TestData.chat("c-1")], isLoading: true, error: "x").viewState,
            .list
        )
    }
}

@MainActor
final class NewsDetailViewModelTests: XCTestCase {

    private func news(id: Int64 = 7) -> News {
        News(
            id: id,
            title: "Title",
            content: "Body",
            imageUrl: nil,
            relatedVideo: nil,
            author: "me",
            publishedAt: "2026-01-01T00:00:00"
        )
    }

    func testLoadStoresNews() async {
        let repository = FakeNewsRepository()
        repository.byId[7] = news()
        let viewModel = NewsDetailViewModel(repository: repository)

        await viewModel.load(id: 7)

        XCTAssertEqual(viewModel.news?.id, 7)
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadErrorIsReported() async {
        let repository = FakeNewsRepository()
        repository.loadError = APIError.server(500, "boom")
        let viewModel = NewsDetailViewModel(repository: repository)

        await viewModel.load(id: 7)

        XCTAssertNil(viewModel.news)
        XCTAssertNotNil(viewModel.error)
    }

    func testDeleteSuccessAndFailure() async {
        let repository = FakeNewsRepository()
        let viewModel = NewsDetailViewModel(repository: repository)

        let deleted = await viewModel.delete(id: 7)
        XCTAssertTrue(deleted)
        XCTAssertEqual(repository.deleted, [7])

        repository.deleteError = APIError.server(500, "boom")
        let failed = await viewModel.delete(id: 8)
        XCTAssertFalse(failed)
        XCTAssertNotNil(viewModel.error)
    }

    func testLoadCommentsRegistersViewOnce() async {
        let repository = FakeNewsRepository()
        repository.byId[7] = news()
        repository.commentsByNews[7] = [
            NewsComment(id: 1, newsId: 7, content: "old", author: "a", createdAt: "2026-01-01T00:00:00"),
            NewsComment(id: 2, newsId: 7, content: "new", author: "b", createdAt: "2026-01-02T00:00:00")
        ]
        let viewModel = NewsDetailViewModel(repository: repository)

        await viewModel.load(id: 7)
        await viewModel.load(id: 7)

        XCTAssertEqual(viewModel.comments.map(\.id), [1, 2])
        XCTAssertEqual(viewModel.commentsTotal, 2)
        XCTAssertFalse(viewModel.hasMoreComments)
        XCTAssertEqual(repository.viewed, [7])
    }

    func testLoadCommentsErrorKeepsArticle() async {
        let repository = FakeNewsRepository()
        repository.byId[7] = news()
        repository.commentsError = APIError.server(500, "boom")
        let viewModel = NewsDetailViewModel(repository: repository)

        await viewModel.load(id: 7)

        XCTAssertEqual(viewModel.news?.id, 7)
        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.comments.isEmpty)
    }

    func testLoadOlderCommentsPrepends() async {
        let repository = FakeNewsRepository()
        repository.byId[7] = news()
        let all = (1...25).map {
            NewsComment(id: Int64($0), newsId: 7, content: "c\($0)", author: "a", createdAt: "2026-01-01T00:00:00")
        }
        repository.commentsByNews[7] = all
        let viewModel = NewsDetailViewModel(repository: repository)

        await viewModel.load(id: 7)
        XCTAssertEqual(viewModel.comments.map(\.id), Array(6...25).map(Int64.init))
        XCTAssertTrue(viewModel.hasMoreComments)

        await viewModel.loadOlderComments()
        XCTAssertEqual(viewModel.comments.count, 25)
        XCTAssertFalse(viewModel.hasMoreComments)
    }

    func testAddCommentAppendsAndReportsError() async {
        let repository = FakeNewsRepository()
        repository.byId[7] = news()
        let viewModel = NewsDetailViewModel(repository: repository)
        await viewModel.load(id: 7)

        let ok = await viewModel.addComment("  Hi  ")
        XCTAssertTrue(ok)
        XCTAssertEqual(repository.addedComments.first?.content, "Hi")
        XCTAssertEqual(viewModel.comments.count, 1)
        XCTAssertEqual(viewModel.commentsTotal, 1)

        repository.addCommentError = APIError.server(500, "boom")
        let failed = await viewModel.addComment("second")
        XCTAssertFalse(failed)
        XCTAssertNotNil(viewModel.error)
    }

    func testDeleteCommentRemovesRow() async {
        let repository = FakeNewsRepository()
        repository.byId[7] = news()
        let comment = NewsComment(id: 3, newsId: 7, content: "c", author: "me", createdAt: "2026-01-01T00:00:00")
        repository.commentsByNews[7] = [comment]
        let viewModel = NewsDetailViewModel(repository: repository)
        await viewModel.load(id: 7)

        await viewModel.deleteComment(comment)

        XCTAssertTrue(viewModel.comments.isEmpty)
        XCTAssertEqual(viewModel.commentsTotal, 0)
        XCTAssertEqual(repository.deletedComments.first?.commentId, 3)
    }

    func testLikeAndUnlikeUpdateState() async {
        let repository = FakeNewsRepository()
        var item = news()
        item.likes = 2
        repository.byId[7] = item
        let viewModel = NewsDetailViewModel(repository: repository)
        await viewModel.load(id: 7)

        await viewModel.toggleLike()
        XCTAssertTrue(viewModel.news?.likedByMe == true)
        XCTAssertEqual(viewModel.news?.likes, 1)
        XCTAssertEqual(repository.likedCalls, [7])

        await viewModel.toggleLike()
        XCTAssertFalse(viewModel.news?.likedByMe == true)
        XCTAssertEqual(repository.unlikedCalls, [7])
    }

    func testLikeErrorRollsBack() async {
        let repository = FakeNewsRepository()
        var item = news()
        item.likes = 2
        repository.byId[7] = item
        repository.likeError = APIError.server(500, "boom")
        let viewModel = NewsDetailViewModel(repository: repository)
        await viewModel.load(id: 7)

        await viewModel.toggleLike()

        XCTAssertFalse(viewModel.news?.likedByMe == true)
        XCTAssertEqual(viewModel.news?.likes, 2)
        XCTAssertNotNil(viewModel.error)
    }
}

@MainActor
final class VideoUploadViewModelTests: XCTestCase {

    func testUploadPassesFieldsAndSucceeds() async {
        let repository = FakeVideoRepository()
        let viewModel = VideoUploadViewModel(repository: repository)

        let ok = await viewModel.upload(
            title: "Trip",
            description: "Sea",
            data: Data([1, 2, 3]),
            fileName: "trip.mp4",
            mimeType: "video/mp4",
            thumbnail: nil
        )

        XCTAssertTrue(ok)
        XCTAssertEqual(repository.uploads.count, 1)
        XCTAssertEqual(repository.uploads.first?.title, "Trip")
        XCTAssertEqual(repository.uploads.first?.fileName, "trip.mp4")
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.isUploading)
    }

    func testUploadErrorIsReported() async {
        let repository = FakeVideoRepository()
        repository.uploadError = APIError.server(413, "too large")
        let viewModel = VideoUploadViewModel(repository: repository)

        let ok = await viewModel.upload(
            title: "Trip",
            description: nil,
            data: Data([1]),
            fileName: "trip.mp4",
            mimeType: "video/mp4",
            thumbnail: nil
        )

        XCTAssertFalse(ok)
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isUploading)
    }
}
