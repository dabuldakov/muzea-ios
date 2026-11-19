import XCTest
@testable import Muzea

/// Ошибочные и краевые ветки ViewModel-ей, которые раньше не покрывались:
/// ошибки репозиториев, пустые идентификаторы, сброс состояния.
@MainActor
final class ViewModelErrorPathTests: XCTestCase {

    private let error = NSError(domain: "test", code: 1)

    // MARK: - ContactListViewModel

    func testContactsLoadErrorIsShown() async {
        let contacts = FakeContactRepository()
        contacts.loadError = error
        let viewModel = ContactListViewModel(
            repository: contacts,
            openPrivateChat: OpenPrivateChatUseCase(repository: FakeChatRepository())
        )

        await viewModel.load()

        XCTAssertNotNil(viewModel.state.error)
        XCTAssertTrue(viewModel.state.contacts.isEmpty)
        XCTAssertFalse(viewModel.state.isLoading)
    }

    func testContactWithoutUuidCannotOpenChat() async {
        let viewModel = ContactListViewModel(
            repository: FakeContactRepository(),
            openPrivateChat: OpenPrivateChatUseCase(repository: FakeChatRepository())
        )

        let chat = await viewModel.openChat(with: contact(uuid: nil))

        XCTAssertNil(chat)
        XCTAssertEqual(viewModel.state.error, L10n.contactNoUuid)
    }

    func testOpenChatErrorIsShown() async {
        let chats = FakeChatRepository()
        chats.createPrivateChatError = error
        let viewModel = ContactListViewModel(
            repository: FakeContactRepository(),
            openPrivateChat: OpenPrivateChatUseCase(repository: chats)
        )

        let chat = await viewModel.openChat(with: contact(uuid: "u-1"))

        XCTAssertNil(chat)
        XCTAssertNotNil(viewModel.state.error)
    }

    func testAddContactErrorIsShownAndConsumed() async {
        let contacts = FakeContactRepository()
        contacts.addError = error
        let viewModel = ContactListViewModel(
            repository: contacts,
            openPrivateChat: OpenPrivateChatUseCase(repository: FakeChatRepository())
        )

        let ok = await viewModel.add(username: "anna")

        XCTAssertFalse(ok)
        XCTAssertNotNil(viewModel.state.error)

        viewModel.consumeError()
        XCTAssertNil(viewModel.state.error)
    }

    // MARK: - CreateGroupViewModel

    func testCreateGroupContactsFailureYieldsEmptyList() async {
        let contacts = FakeContactRepository()
        contacts.loadError = error
        let viewModel = CreateGroupViewModel(
            chatRepository: FakeChatRepository(),
            contactRepository: contacts
        )

        await viewModel.loadContacts()

        XCTAssertTrue(viewModel.contacts.isEmpty)
        XCTAssertFalse(viewModel.isLoadingContacts)
    }

    func testCreateGroupErrorIsShownAndCanBeConsumed() async {
        let chats = FakeChatRepository()
        chats.createGroupError = error
        let viewModel = CreateGroupViewModel(
            chatRepository: chats,
            contactRepository: FakeContactRepository()
        )

        let chat = await viewModel.create(title: "Team", memberUuids: ["u-1"])

        XCTAssertNil(chat)
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isSubmitting)

        viewModel.consumeError()
        XCTAssertNil(viewModel.error)
    }

    // MARK: - GroupSettingsViewModel

    func testAddMembersErrorIsShown() async {
        let chats = FakeChatRepository()
        chats.participants["c-1"] = [participant("u-1")]
        chats.addParticipantsError = error
        let viewModel = makeGroupViewModel(chats: chats)

        let ok = await viewModel.addMembers(["u-2"])

        XCTAssertFalse(ok)
        XCTAssertNotNil(viewModel.state.error)
        XCTAssertTrue(chats.addedParticipants.isEmpty)
    }

    func testAvatarUploadErrorResetsProgressAndAllowsRetry() async {
        let avatars = FakeAvatarRepository()
        avatars.chatAvatarError = error
        let viewModel = makeGroupViewModel(avatars: avatars)

        await viewModel.uploadAvatar(data: Data([1]), fileName: "a.jpg", mimeType: "image/jpeg")

        XCTAssertNotNil(viewModel.state.error)
        XCTAssertFalse(viewModel.state.isUploading)
        XCTAssertEqual(viewModel.avatarUrl, "/old.png")

        avatars.chatAvatarError = nil
        avatars.chatAvatar = "/new.png"
        await viewModel.uploadAvatar(data: Data([1]), fileName: "a.jpg", mimeType: "image/jpeg")

        XCTAssertEqual(viewModel.avatarUrl, "/new.png")
        XCTAssertNil(viewModel.state.error)
    }

    func testGroupValidationErrorAndConsume() async {
        let viewModel = makeGroupViewModel()

        viewModel.reportValidationError("too big")
        XCTAssertEqual(viewModel.state.error, "too big")

        viewModel.consumeError()
        XCTAssertNil(viewModel.state.error)
    }

    func testGroupLoadParticipantsErrorIsShown() async {
        let chats = FakeChatRepository()
        chats.loadParticipantsError = error
        let viewModel = makeGroupViewModel(chats: chats)

        await viewModel.load()

        XCTAssertNotNil(viewModel.state.error)
        XCTAssertFalse(viewModel.state.isLoading)
    }

    // MARK: - GifSearchViewModel

    func testLoadIfNeededCallsRepositoryOnce() async {
        let repository = PagedGifRepository()
        repository.recentPages[0] = [gif(0)]
        let viewModel = GifSearchViewModel(repository: repository, chatUuid: "c-1")

        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.gifs.count, 1)
        XCTAssertEqual(repository.recentCalls, 1)
    }

    func testPaginationStopsOnShortPage() async {
        let repository = PagedGifRepository()
        repository.recentPages[0] = (0..<GifSearchViewModel.pageSize).map { gif($0) }
        repository.recentPages[1] = [gif(100), gif(101)]
        let viewModel = GifSearchViewModel(repository: repository, chatUuid: "c-1")

        await viewModel.loadIfNeeded()
        XCTAssertTrue(viewModel.hasMore)

        await viewModel.loadNextPage()

        XCTAssertEqual(viewModel.gifs.count, GifSearchViewModel.pageSize + 2)
        XCTAssertFalse(viewModel.hasMore)
        XCTAssertEqual(repository.recentCalls, 2)

        await viewModel.loadNextPage()
        XCTAssertEqual(repository.recentCalls, 2)
    }

    func testSearchOutsideSearchTabOnlyUpdatesQuery() async {
        let repository = PagedGifRepository()
        repository.searchPages[0] = [gif(1)]
        let viewModel = GifSearchViewModel(repository: repository, chatUuid: "c-1")

        await viewModel.search(query: "cat")

        XCTAssertEqual(viewModel.query, "cat")
        XCTAssertEqual(repository.searchCalls, 0)

        await viewModel.select(.search)

        XCTAssertEqual(repository.searchCalls, 1)
        XCTAssertEqual(repository.lastQuery, "cat")
        XCTAssertEqual(viewModel.gifs.count, 1)
    }

    func testReloadResetsPagination() async {
        let repository = PagedGifRepository()
        repository.recentPages[0] = (0..<GifSearchViewModel.pageSize).map { gif($0) }
        repository.recentPages[1] = [gif(100)]
        let viewModel = GifSearchViewModel(repository: repository, chatUuid: "c-1")

        await viewModel.loadIfNeeded()
        await viewModel.loadNextPage()
        XCTAssertEqual(viewModel.gifs.count, GifSearchViewModel.pageSize + 1)

        await viewModel.reload()

        XCTAssertEqual(viewModel.gifs.count, GifSearchViewModel.pageSize)
        XCTAssertTrue(viewModel.hasMore)
        XCTAssertEqual(repository.recentCalls, 3)
    }

    // MARK: - NewsListViewModel

    func testNewsLoadErrorIsShown() async {
        let repository = FakeNewsRepository()
        repository.loadError = error
        let viewModel = NewsListViewModel(
            newsRepository: repository,
            contactRepository: FakeContactRepository(),
            ownUsername: "me"
        )

        await viewModel.load()

        XCTAssertNotNil(viewModel.state.error)
        XCTAssertTrue(viewModel.state.news.isEmpty)
        XCTAssertFalse(viewModel.state.isLoading)
    }

    // MARK: - Helpers

    private func contact(uuid: String?) -> Contact {
        Contact(
            contactUuid: "k-1",
            contactUserId: nil,
            contactUserUuid: uuid,
            username: "anna",
            firstName: nil,
            lastName: nil,
            fullName: nil,
            avatarUrl: nil,
            contactName: nil,
            isOnline: false,
            lastSeenAt: nil,
            addedAt: nil
        )
    }

    private func participant(_ uuid: String) -> ChatParticipant {
        ChatParticipant(
            userUuid: uuid,
            userId: nil,
            username: uuid,
            firstName: nil,
            lastName: nil,
            fullName: nil,
            nickname: nil,
            avatarUrl: nil,
            role: "MEMBER",
            online: nil,
            lastSeenAt: nil,
            joinedAt: nil
        )
    }

    private func makeGroupViewModel(
        chats: FakeChatRepository = FakeChatRepository(),
        avatars: FakeAvatarRepository = FakeAvatarRepository()
    ) -> GroupSettingsViewModel {
        GroupSettingsViewModel(
            chatUuid: "c-1",
            myUserUuid: "me",
            initialAvatarUrl: "/old.png",
            chatRepository: chats,
            contactRepository: FakeContactRepository(),
            avatarRepository: avatars
        )
    }

    private func gif(_ index: Int) -> Gif {
        Gif(
            provider: "klipy",
            providerGifId: "g-\(index)",
            title: nil,
            url: "https://cdn/\(index).mp4",
            previewUrl: nil,
            mp4Url: nil,
            width: nil,
            height: nil,
            gifKey: nil
        )
    }
}

/// GIF-репозиторий с постраничными ответами: нужен, чтобы проверить
/// пагинацию и `hasMore`, которые фиксированный фейк не покрывает.
private final class PagedGifRepository: GifRepository {
    var recentPages: [Int: [Gif]] = [:]
    var chatPages: [Int: [Gif]] = [:]
    var searchPages: [Int: [Gif]] = [:]

    private(set) var recentCalls = 0
    private(set) var searchCalls = 0
    private(set) var lastQuery: String?

    func search(query: String, page: Int, size: Int) async -> [Gif] {
        searchCalls += 1
        lastQuery = query
        return searchPages[page] ?? []
    }

    func recent(page: Int, size: Int) async -> [Gif] {
        recentCalls += 1
        return recentPages[page] ?? []
    }

    func chat(chatUuid: String, page: Int, size: Int) async -> [Gif] {
        chatPages[page] ?? []
    }
}
