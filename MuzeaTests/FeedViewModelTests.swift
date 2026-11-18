import XCTest
@testable import Muzea

@MainActor
final class NewsListViewModelTests: XCTestCase {

    private func news(_ id: Int64, author: String) -> News {
        News(
            id: id,
            title: "News \(id)",
            content: "Body",
            imageUrl: nil,
            relatedVideo: nil,
            author: author,
            publishedAt: "2026-01-01T00:00:00"
        )
    }

    func testLoadKeepsOnlyContactsAndOwnPosts() async {
        let repository = FakeNewsRepository()
        repository.pages = [
            Page(
                content: [
                    news(1, author: "friend"),
                    news(2, author: "stranger"),
                    news(3, author: "me")
                ],
                totalElements: 3,
                totalPages: 1,
                number: 0
            )
        ]
        let contacts = FakeContactRepository()
        contacts.contacts = [TestData.contact("friend")]
        let viewModel = NewsListViewModel(
            newsRepository: repository,
            contactRepository: contacts,
            ownUsername: "me"
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.state.news.map(\.id), [1, 3])
        XCTAssertTrue(viewModel.state.endReached)
        XCTAssertNil(viewModel.state.error)
        XCTAssertFalse(viewModel.state.isLoading)
    }

    func testRefreshReloadsContacts() async {
        let repository = FakeNewsRepository()
        repository.pages = [
            Page(
                content: [news(1, author: "friend"), news(2, author: "bob")],
                totalElements: 2,
                totalPages: 1,
                number: 0
            )
        ]
        let contacts = FakeContactRepository()
        contacts.contacts = [TestData.contact("friend")]
        let viewModel = NewsListViewModel(
            newsRepository: repository,
            contactRepository: contacts,
            ownUsername: "me"
        )
        await viewModel.load()
        XCTAssertEqual(viewModel.state.news.map(\.id), [1])

        contacts.contacts = [TestData.contact("friend"), TestData.contact("bob")]
        await viewModel.load(reset: true)

        XCTAssertEqual(viewModel.state.news.map(\.id), [1, 2])
    }

    func testShortPageMarksEndReached() async {
        let repository = FakeNewsRepository()
        repository.pages = [Page(content: [], totalElements: 0, totalPages: 0, number: 0)]
        let viewModel = NewsListViewModel(
            newsRepository: repository,
            contactRepository: FakeContactRepository(),
            ownUsername: "me"
        )

        await viewModel.load()

        XCTAssertTrue(viewModel.state.news.isEmpty)
        XCTAssertTrue(viewModel.state.endReached)
    }

    func testLoadErrorIsReported() async {
        let repository = FakeNewsRepository()
        repository.loadError = APIError.server(500, "boom")
        let viewModel = NewsListViewModel(
            newsRepository: repository,
            contactRepository: FakeContactRepository(),
            ownUsername: "me"
        )

        await viewModel.load()

        XCTAssertNotNil(viewModel.state.error)
        XCTAssertFalse(viewModel.state.isLoading)
    }

    func testDeleteRemovesItemAndReportsFailure() async {
        let repository = FakeNewsRepository()
        repository.pages = [
            Page(content: [news(1, author: "me")], totalElements: 1, totalPages: 1, number: 0)
        ]
        let viewModel = NewsListViewModel(
            newsRepository: repository,
            contactRepository: FakeContactRepository(),
            ownUsername: "me"
        )
        await viewModel.load()

        let deleted = await viewModel.delete(news(1, author: "me"))
        XCTAssertTrue(deleted)
        XCTAssertEqual(repository.deleted, [1])
        XCTAssertTrue(viewModel.state.news.isEmpty)

        repository.deleteError = APIError.server(500, "boom")
        let failed = await viewModel.delete(news(1, author: "me"))
        XCTAssertFalse(failed)
        XCTAssertNotNil(viewModel.state.error)
    }

    func testConsumeErrorClearsMessage() async {
        let repository = FakeNewsRepository()
        repository.loadError = APIError.server(500, "boom")
        let viewModel = NewsListViewModel(
            newsRepository: repository,
            contactRepository: FakeContactRepository(),
            ownUsername: "me"
        )
        await viewModel.load()

        viewModel.consumeError()

        XCTAssertNil(viewModel.state.error)
    }
}

@MainActor
final class VideoFeedViewModelTests: XCTestCase {

    private func video(_ id: Int64, author: String) -> Video {
        Video(
            id: id,
            title: "Video \(id)",
            description: nil,
            url: "/api/videos/stream/\(id).mp4",
            thumbnailUrl: nil,
            fileSize: nil,
            durationSeconds: nil,
            views: 0,
            likes: nil,
            likedByMe: nil,
            uploadedBy: author,
            uploadedAt: "2026-01-01T00:00:00"
        )
    }

    func testStartsWithFilteredCache() {
        let repository = FakeVideoRepository()
        repository.cached = [video(1, author: "me"), video(2, author: "stranger")]

        let viewModel = VideoListViewModel(repository: repository, ownUsername: "me")

        XCTAssertEqual(viewModel.state.videos.map(\.id), [1])
    }

    func testLoadReplacesWithServerListAndReportsError() async {
        let repository = FakeVideoRepository()
        repository.videos = [video(1, author: "me"), video(2, author: "other")]
        let viewModel = VideoListViewModel(repository: repository, ownUsername: "me")

        await viewModel.load()
        XCTAssertEqual(viewModel.state.videos.map(\.id), [1])

        // Ошибка чтения списка проверяется через отдельный фейк ниже.
        let failing = FailingVideoRepository()
        let failingVM = VideoListViewModel(repository: failing, ownUsername: "me")
        await failingVM.load()
        XCTAssertNotNil(failingVM.state.error)
        XCTAssertFalse(failingVM.state.isLoading)
    }

    func testVideoDetailDeleteSuccessAndFailure() async {
        let repository = FakeVideoRepository()
        let viewModel = VideoDetailViewModel(repository: repository)

        let deleted = await viewModel.delete(id: 3)
        XCTAssertTrue(deleted)
        XCTAssertEqual(repository.deleted, [3])
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.isDeleting)

        let failing = FailingVideoRepository()
        let failingVM = VideoDetailViewModel(repository: failing)
        let failed = await failingVM.delete(id: 4)
        XCTAssertFalse(failed)
        XCTAssertNotNil(failingVM.error)
        XCTAssertFalse(failingVM.isDeleting)
    }
}

private final class FailingVideoRepository: VideoRepository {
    func getVideos() async throws -> [Video] { throw APIError.server(500, "boom") }
    func cachedVideos() -> [Video] { [] }
    func getVideoById(_ id: Int64) async throws -> Video { throw APIError.server(404, "not found") }
    func uploadVideo(
        title: String,
        description: String?,
        data: Data,
        fileName: String,
        mimeType: String,
        thumbnail: UploadFile?
    ) async throws -> Video {
        throw APIError.server(500, "boom")
    }
    func deleteVideo(_ id: Int64) async throws { throw APIError.server(500, "boom") }
}

@MainActor
final class CreateNewsViewModelTests: XCTestCase {

    private func video(_ id: Int64, author: String) -> Video {
        Video(
            id: id,
            title: "Video \(id)",
            description: nil,
            url: "/api/videos/stream/\(id).mp4",
            thumbnailUrl: nil,
            fileSize: nil,
            durationSeconds: nil,
            views: 0,
            likes: nil,
            likedByMe: nil,
            uploadedBy: author,
            uploadedAt: "2026-01-01T00:00:00"
        )
    }

    func testLoadVideosKeepsOnlyOwn() async {
        let videos = FakeVideoRepository()
        videos.videos = [video(1, author: "me"), video(2, author: "other")]
        let viewModel = CreateNewsViewModel(
            newsRepository: FakeNewsRepository(),
            videoRepository: videos
        )

        await viewModel.loadVideos(ownUsername: "me")

        XCTAssertEqual(viewModel.ownVideos.map(\.id), [1])
    }

    func testSubmitPassesFieldsAndSucceeds() async {
        let news = FakeNewsRepository()
        let viewModel = CreateNewsViewModel(
            newsRepository: news,
            videoRepository: FakeVideoRepository()
        )

        let ok = await viewModel.submit(
            title: "Trip",
            content: "Sea",
            videoId: 9,
            image: UploadFile(data: Data([1]), fileName: "a.jpg", mimeType: "image/jpeg")
        )

        XCTAssertTrue(ok)
        XCTAssertEqual(news.created.first?.title, "Trip")
        XCTAssertEqual(news.created.first?.content, "Sea")
        XCTAssertEqual(news.created.first?.videoId, 9)
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.isSubmitting)
    }

    func testSubmitErrorIsReported() async {
        let news = FakeNewsRepository()
        news.createError = APIError.server(500, "boom")
        let viewModel = CreateNewsViewModel(
            newsRepository: news,
            videoRepository: FakeVideoRepository()
        )

        let ok = await viewModel.submit(title: "T", content: "C", videoId: nil, image: nil)

        XCTAssertFalse(ok)
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isSubmitting)
    }

    func testConsumeErrorClearsMessage() async {
        let news = FakeNewsRepository()
        news.createError = APIError.server(500, "boom")
        let viewModel = CreateNewsViewModel(
            newsRepository: news,
            videoRepository: FakeVideoRepository()
        )
        _ = await viewModel.submit(title: "T", content: "C", videoId: nil, image: nil)

        viewModel.consumeError()

        XCTAssertNil(viewModel.error)
    }
}
