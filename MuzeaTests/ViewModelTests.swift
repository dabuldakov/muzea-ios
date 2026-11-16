import XCTest
@testable import Muzea

@MainActor
final class ChatConversationViewModelTests: XCTestCase {

    func testSeedsFromCacheSorted() {
        let repository = FakeMessageRepository()
        repository.cached = [
            TestData.message("m2", createdAt: "2026-01-01T00:00:02"),
            TestData.message("m1", createdAt: "2026-01-01T00:00:01")
        ]

        let viewModel = ChatConversationViewModel(
            chatUuid: "c-1",
            myUserUuid: "me",
            isGroupChat: false,
            services: .fake(messages: repository)
        )

        XCTAssertEqual(viewModel.state.messages.map(\.messageUuid), ["m1", "m2"])
    }

    func testSendKeepsLocalBubbleAndDedupesServerEcho() async {
        let repository = FakeMessageRepository()
        repository.sendResult = TestData.message("server-1", text: "hi", createdAt: "2026-01-01T00:00:02")
        let viewModel = ChatConversationViewModel(
            chatUuid: "c-1",
            myUserUuid: "me",
            isGroupChat: false,
            services: .fake(messages: repository)
        )

        await viewModel.send("hi")

        XCTAssertEqual(viewModel.state.messages.count, 1)
        let localUuid = try? XCTUnwrap(viewModel.state.messages.first?.messageUuid)
        XCTAssertEqual(localUuid?.hasPrefix("local-"), true)
        XCTAssertEqual(viewModel.state.messages.first?.text, "hi")

        // Серверное эхо прилетает опросом — оно не должно продублировать пузырь.
        repository.messages = [TestData.message("server-1", text: "hi", createdAt: "2026-01-01T00:00:02")]
        await viewModel.refresh()

        XCTAssertEqual(viewModel.state.messages.count, 1)
        XCTAssertEqual(viewModel.state.messages.first?.messageUuid, localUuid)
    }

    func testRefreshDoesNotMarkUnseenMessagesRead() async {
        let repository = FakeMessageRepository()
        repository.messages = [
            TestData.message("s1", createdAt: "2026-01-01T00:00:01"),
            TestData.message("s2", createdAt: "2026-01-01T00:00:02")
        ]
        let viewModel = ChatConversationViewModel(
            chatUuid: "c-1",
            myUserUuid: "me",
            isGroupChat: false,
            services: .fake(messages: repository)
        )

        await viewModel.refresh()

        XCTAssertTrue(repository.markedRead.isEmpty)
    }

    func testMarkReadUpToMovesOnlyForward() async {
        let repository = FakeMessageRepository()
        let first = TestData.message("s1", createdAt: "2026-01-01T00:00:01")
            .replacing(messageId: 10)
        let second = TestData.message("s2", createdAt: "2026-01-01T00:00:02")
            .replacing(messageId: 11)
        repository.messages = [first, second]
        let viewModel = ChatConversationViewModel(
            chatUuid: "c-1",
            myUserUuid: "me",
            isGroupChat: false,
            services: .fake(messages: repository)
        )
        await viewModel.refresh()

        await viewModel.markReadUpTo(second)
        await viewModel.markReadUpTo(first)

        XCTAssertEqual(repository.markedRead.count, 1)
        XCTAssertEqual(repository.markedRead.first?.1, "s2")
    }

    func testSendIgnoresBlankText() async {
        let repository = FakeMessageRepository()
        let viewModel = ChatConversationViewModel(
            chatUuid: "c-1",
            myUserUuid: "me",
            isGroupChat: false,
            services: .fake(messages: repository)
        )

        await viewModel.send("   ")

        XCTAssertTrue(repository.sentTexts.isEmpty)
        XCTAssertTrue(viewModel.state.messages.isEmpty)
    }
}

@MainActor
final class ContactListViewModelTests: XCTestCase {

    private func makeViewModel(
        contacts: FakeContactRepository,
        chats: FakeChatRepository = FakeChatRepository()
    ) -> ContactListViewModel {
        ContactListViewModel(repository: contacts, openPrivateChat: OpenPrivateChatUseCase(repository: chats))
    }

    func testLoadPopulatesContacts() async {
        let contacts = FakeContactRepository()
        contacts.contacts = [TestData.contact("u-1")]
        let viewModel = makeViewModel(contacts: contacts)

        await viewModel.load()

        XCTAssertEqual(viewModel.state.contacts.count, 1)
        XCTAssertNil(viewModel.state.error)
    }

    func testRefreshPresenceMergesWithoutReordering() async {
        let contacts = FakeContactRepository()
        contacts.contacts = [TestData.contact("u-1"), TestData.contact("u-2")]
        let viewModel = makeViewModel(contacts: contacts)
        await viewModel.load()

        contacts.presence = ["u-1": PresenceResponse(userUuid: "u-1", online: true, lastSeenAt: nil)]
        await viewModel.refreshPresence()

        XCTAssertEqual(viewModel.state.contacts.map { $0.contactUserUuid }, ["u-1", "u-2"])
        XCTAssertTrue(viewModel.state.contacts[0].isOnline)
        XCTAssertFalse(viewModel.state.contacts[1].isOnline)
    }

    func testRefreshPresenceIgnoresEmptyResponse() async {
        let contacts = FakeContactRepository()
        contacts.contacts = [TestData.contact("u-1", online: true)]
        let viewModel = makeViewModel(contacts: contacts)
        await viewModel.load()

        contacts.presence = [:]
        await viewModel.refreshPresence()

        XCTAssertTrue(viewModel.state.contacts[0].isOnline)
    }

    func testOpenChatReusesExistingPrivateChat() async {
        let contacts = FakeContactRepository()
        let chats = FakeChatRepository()
        chats.privateChats["u-1"] = TestData.chat("existing")
        let viewModel = makeViewModel(contacts: contacts, chats: chats)

        let chat = await viewModel.openChat(with: TestData.contact("u-1"))

        XCTAssertEqual(chat?.chatUuid, "existing")
        XCTAssertTrue(chats.createdPrivateChats.isEmpty)
    }

    func testAddReloadsContacts() async {
        let contacts = FakeContactRepository()
        let viewModel = makeViewModel(contacts: contacts)

        let ok = await viewModel.add(username: "alice")

        XCTAssertTrue(ok)
        XCTAssertEqual(contacts.added, ["alice"])
    }
}

@MainActor
final class VideoListViewModelTests: XCTestCase {

    private func video(_ id: Int64, by author: String) -> VideoResponse {
        VideoResponse(
            id: id,
            title: "V\(id)",
            description: nil,
            url: "",
            thumbnailUrl: nil,
            fileSize: nil,
            durationSeconds: nil,
            views: 0,
            likes: nil,
            likedByMe: nil,
            uploadedBy: author,
            uploadedAt: ""
        )
    }

    func testSeedsFromCacheFilteredToOwn() {
        let repository = FakeVideoRepository()
        repository.cached = [video(1, by: "me"), video(2, by: "other")]

        let viewModel = VideoListViewModel(repository: repository, ownUsername: "me")

        XCTAssertEqual(viewModel.state.videos.map(\.id), [1])
    }

    func testLoadFiltersToOwn() async {
        let repository = FakeVideoRepository()
        repository.videos = [video(1, by: "me"), video(2, by: "other")]
        let viewModel = VideoListViewModel(repository: repository, ownUsername: "me")

        await viewModel.load()

        XCTAssertEqual(viewModel.state.videos.map(\.id), [1])
        XCTAssertFalse(viewModel.state.isLoading)
    }
}

@MainActor
final class AuthViewModelTests: XCTestCase {

    func testRequestLoginCodeMovesToCodePhase() async {
        let repository = FakeAuthRepository()
        let viewModel = AuthViewModel(repository: repository)

        let ok = await viewModel.requestLoginCode(email: " Alice@Example.com ")

        XCTAssertTrue(ok)
        XCTAssertEqual(repository.requestedCodes, ["alice@example.com"])
        XCTAssertEqual(viewModel.state.phase, .code)
        XCTAssertEqual(viewModel.state.flow, .login)
        XCTAssertNil(viewModel.state.error)
        XCTAssertFalse(viewModel.state.isLoading)
    }

    func testInvalidEmailDoesNotCallRepository() async {
        let repository = FakeAuthRepository()
        let viewModel = AuthViewModel(repository: repository)

        let ok = await viewModel.requestLoginCode(email: "not-an-email")

        XCTAssertFalse(ok)
        XCTAssertTrue(repository.requestedCodes.isEmpty)
        XCTAssertEqual(viewModel.state.phase, .email)
        XCTAssertNotNil(viewModel.state.error)
    }

    func testVerifyLoginCodeSuccess() async {
        let repository = FakeAuthRepository()
        let viewModel = AuthViewModel(repository: repository)
        _ = await viewModel.requestLoginCode(email: "alice@example.com")

        let ok = await viewModel.verify(code: " 123456 ")

        XCTAssertTrue(ok)
        XCTAssertEqual(repository.verifiedLogins.count, 1)
        XCTAssertEqual(repository.verifiedLogins.first?.0, "alice@example.com")
        XCTAssertEqual(repository.verifiedLogins.first?.1, "123456")
    }

    func testRegisterSuccessMovesToCodePhase() async {
        let repository = FakeAuthRepository()
        let viewModel = AuthViewModel(repository: repository)

        let ok = await viewModel.register(
            email: "a@b.c",
            username: "alice",
            displayName: "Alice"
        )

        XCTAssertTrue(ok)
        XCTAssertEqual(viewModel.state.phase, .code)
        XCTAssertEqual(viewModel.state.flow, .register)
        XCTAssertEqual(repository.registered.first?.0, "a@b.c")
        XCTAssertEqual(repository.registered.first?.1, "alice")
        XCTAssertEqual(repository.registered.first?.2, "Alice")
    }

    func testRegisterValidation() async {
        let repository = FakeAuthRepository()
        let viewModel = AuthViewModel(repository: repository)

        let ok = await viewModel.register(email: "a@b.c", username: "a", displayName: "")

        XCTAssertFalse(ok)
        XCTAssertTrue(repository.registered.isEmpty)
        XCTAssertNotNil(viewModel.state.error)
    }

    func testVerifyRegisterUsesEmailEndpoint() async {
        let repository = FakeAuthRepository()
        let viewModel = AuthViewModel(repository: repository)
        _ = await viewModel.register(email: "a@b.c", username: "alice", displayName: "")

        let ok = await viewModel.verify(code: "000000")

        XCTAssertTrue(ok)
        XCTAssertEqual(repository.verifiedEmails.count, 1)
        XCTAssertTrue(repository.verifiedLogins.isEmpty)
    }

    func testResendRoutesByFlow() async {
        let repository = FakeAuthRepository()
        let viewModel = AuthViewModel(repository: repository)

        _ = await viewModel.requestLoginCode(email: "alice@example.com")
        _ = await viewModel.resend()
        XCTAssertEqual(repository.requestedCodes.count, 2)
        XCTAssertTrue(repository.resent.isEmpty)

        viewModel.backToEmail()
        _ = await viewModel.register(email: "a@b.c", username: "alice", displayName: "")
        _ = await viewModel.resend()
        XCTAssertEqual(repository.resent, ["a@b.c"])
    }

    func testErrorIsLocalizedByCode() async {
        let repository = FakeAuthRepository()
        repository.requestCodeError = APIError.server(
            429,
            #"{"code":"otp_cooldown","message":"Please wait before requesting a new code"}"#
        )
        let viewModel = AuthViewModel(repository: repository)

        let ok = await viewModel.requestLoginCode(email: "alice@example.com")

        XCTAssertFalse(ok)
        XCTAssertEqual(viewModel.state.error, "Подождите немного перед повторной отправкой.")
    }
}

@MainActor
final class GroupSettingsViewModelTests: XCTestCase {

    private func participant(_ uuid: String) -> ChatParticipantResponse {
        ChatParticipantResponse(
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

    private func makeViewModel() -> (GroupSettingsViewModel, FakeChatRepository, FakeAvatarRepository) {
        let chats = FakeChatRepository()
        chats.participants["c-1"] = [participant("u-1")]
        let avatars = FakeAvatarRepository()
        avatars.chatAvatar = "/new.png"
        let viewModel = GroupSettingsViewModel(
            chatUuid: "c-1",
            myUserUuid: "me",
            initialAvatarUrl: "/old.png",
            chatRepository: chats,
            contactRepository: FakeContactRepository(),
            avatarRepository: avatars
        )
        return (viewModel, chats, avatars)
    }

    func testLoadParticipants() async {
        let (viewModel, _, _) = makeViewModel()

        await viewModel.load()

        XCTAssertEqual(viewModel.state.participants.count, 1)
        XCTAssertFalse(viewModel.state.isLoading)
    }

    func testAddMembersDelegatesToRepository() async {
        let (viewModel, chats, _) = makeViewModel()

        let ok = await viewModel.addMembers(["u-2", "u-3"])

        XCTAssertTrue(ok)
        XCTAssertEqual(chats.addedParticipants.first?.0, "c-1")
        XCTAssertEqual(chats.addedParticipants.first?.1, ["u-2", "u-3"])
    }

    func testUploadAvatarUpdatesUrl() async {
        let (viewModel, _, _) = makeViewModel()

        await viewModel.uploadAvatar(data: Data([1]), fileName: "a.jpg", mimeType: "image/jpeg")

        XCTAssertEqual(viewModel.avatarUrl, "/new.png")
        XCTAssertFalse(viewModel.state.isUploading)
    }
}

@MainActor
final class CreateGroupViewModelTests: XCTestCase {

    func testCreateTrimsTitleAndDelegates() async {
        let chats = FakeChatRepository()
        let viewModel = CreateGroupViewModel(chatRepository: chats, contactRepository: FakeContactRepository())

        let chat = await viewModel.create(title: "  Team  ", memberUuids: ["a"])

        XCTAssertEqual(chat?.title, "Team")
        XCTAssertEqual(chats.createdGroups.first?.0, "Team")
        XCTAssertEqual(chats.createdGroups.first?.1, ["a"])
    }

    func testCreateRejectsBlankTitle() async {
        let chats = FakeChatRepository()
        let viewModel = CreateGroupViewModel(chatRepository: chats, contactRepository: FakeContactRepository())

        let chat = await viewModel.create(title: "   ", memberUuids: [])

        XCTAssertNil(chat)
        XCTAssertTrue(chats.createdGroups.isEmpty)
    }
}

@MainActor
final class ProfileViewModelTests: XCTestCase {

    private let user = UserResponse(
        id: 7,
        userName: "me",
        email: "me@example.com",
        fullName: "Me",
        avatarUrl: nil,
        role: "USER",
        createdAt: nil,
        enabled: true
    )

    func testLoadPopulatesUserAndAvatar() async {
        let users = FakeUserRepository()
        users.user = user
        let avatars = FakeAvatarRepository()
        avatars.avatar = "/a.png"
        let viewModel = ProfileViewModel(
            userRepository: users,
            avatarRepository: avatars,
            chatSessionRepository: FakeChatSessionRepository(),
            authRepository: FakeAuthRepository()
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.state.user?.id, 7)
        XCTAssertEqual(viewModel.state.avatarUrl, "/a.png")
        XCTAssertEqual(viewModel.state.email, "alice@example.com")
    }

    func testUpdateDelegatesToRepository() async {
        let users = FakeUserRepository()
        users.user = user
        let viewModel = ProfileViewModel(
            userRepository: users,
            avatarRepository: FakeAvatarRepository(),
            chatSessionRepository: FakeChatSessionRepository(),
            authRepository: FakeAuthRepository(),
            initialUser: user
        )

        let ok = await viewModel.update(fullName: "New", email: "new@example.com")

        XCTAssertTrue(ok)
    }
}
