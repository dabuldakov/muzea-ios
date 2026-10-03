import XCTest
@testable import Muzea

final class NewsRepositoryTests: XCTestCase {

    private var store: TokenStore!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        store = TestSupport.makeStore()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        store = nil
        super.tearDown()
    }

    private func repository() -> NewsRepositoryImpl {
        NewsRepositoryImpl(client: TestSupport.makeupClient(tokenStore: store))
    }

    func testGetNewsSendsPagingQuery() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"content":[],"totalElements":0}"#))
        }

        _ = try await repository().getNews(page: 2, size: 20)

        let url = try XCTUnwrap(MockURLProtocol.requests.first?.url)
        XCTAssertEqual(url.path, "/api/news")
        XCTAssertEqual(url.query, "page=2&size=20")
    }

    func testGetNewsByIdUsesPath() async throws {
        MockURLProtocol.handler = { request in
            let json = #"{"id":5,"title":"T","content":"C","imageUrl":null,"publishedAt":"2026-01-01T00:00:00","author":"a","relatedVideo":null}"#
            return (MockURLProtocol.response(for: request), TestSupport.data(json))
        }

        let news = try await repository().getNewsById(5)

        XCTAssertEqual(news.id, 5)
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/news/5")
    }

    func testCreateNewsWithImageUsesMultipart() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"id":9}"#))
        }

        _ = try await repository().createNews(
            title: "T",
            content: "C",
            videoId: 3,
            image: UploadFile(data: Data([1]), fileName: "p.jpg", mimeType: "image/jpeg")
        )

        let body = try XCTUnwrap(MockURLProtocol.requests.first?.capturedBody)
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/news")
        XCTAssertTrue(text.contains("name=\"title\""))
        XCTAssertTrue(text.contains("name=\"content\""))
        XCTAssertTrue(text.contains("name=\"videoId\""))
        XCTAssertTrue(text.contains("name=\"image\"; filename=\"p.jpg\""))
    }

    func testCreateNewsWithoutImageUsesFormFields() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"id":9}"#))
        }

        _ = try await repository().createNews(title: "T", content: "C", videoId: nil, image: nil)

        let body = try XCTUnwrap(MockURLProtocol.requests.first?.capturedBody)
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(text.contains("name=\"title\""))
        XCTAssertFalse(text.contains("filename="))
    }

    func testDeleteNewsUsesDelete() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 204), Data())
        }

        try await repository().deleteNews(4)

        XCTAssertEqual(MockURLProtocol.requests.first?.httpMethod, "DELETE")
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/news/4")
    }
}

final class VideoRepositoryTests: XCTestCase {

    private var store: TokenStore!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        store = TestSupport.makeStore()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        store = nil
        super.tearDown()
    }

    private func repository() -> VideoRepositoryImpl {
        VideoRepositoryImpl(client: TestSupport.makeupClient(tokenStore: store), cache: VideoListCache())
    }

    private let videoJSON = #"{"id":1,"title":"V","description":null,"url":"/api/videos/stream/x.mp4","thumbnailUrl":null,"fileSize":null,"durationSeconds":null,"views":0,"likes":null,"likedByMe":null,"uploadedBy":"me","uploadedAt":"2026-01-01T00:00:00"}"#

    func testGetVideos() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data("[\(self.videoJSON)]"))
        }

        let videos = try await repository().getVideos()

        XCTAssertEqual(videos.count, 1)
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/videos")
    }

    func testGetVideoById() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(self.videoJSON))
        }

        let video = try await repository().getVideoById(1)

        XCTAssertEqual(video.id, 1)
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/videos/1")
    }

    func testUploadVideoIncludesThumbnail() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(self.videoJSON))
        }

        _ = try await repository().uploadVideo(
            title: "T",
            description: "D",
            data: Data([1, 2]),
            fileName: "v.mp4",
            mimeType: "video/mp4",
            thumbnail: UploadFile(data: Data([3]), fileName: "thumbnail.jpeg", mimeType: "image/jpeg")
        )

        let body = try XCTUnwrap(MockURLProtocol.requests.first?.capturedBody)
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/videos/upload")
        XCTAssertTrue(text.contains("name=\"title\""))
        XCTAssertTrue(text.contains("name=\"description\""))
        XCTAssertTrue(text.contains("name=\"file\"; filename=\"v.mp4\""))
        XCTAssertTrue(text.contains("name=\"thumbnail\"; filename=\"thumbnail.jpeg\""))
    }

    func testUploadVideoWithoutThumbnail() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(self.videoJSON))
        }

        _ = try await repository().uploadVideo(
            title: "T",
            description: nil,
            data: Data([1]),
            fileName: "v.mp4",
            mimeType: "video/mp4"
        )

        let body = try XCTUnwrap(MockURLProtocol.requests.first?.capturedBody)
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertFalse(text.contains("name=\"thumbnail\""))
    }

    func testDeleteVideo() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 204), Data())
        }

        try await repository().deleteVideo(7)

        XCTAssertEqual(MockURLProtocol.requests.first?.httpMethod, "DELETE")
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/videos/7")
    }
}

/// Набор SRP-репозиториев чата, разделяющих одну авторизацию, — как в проде.
struct ChatKit {
    let auth: ChatAuthManager
    let chats: ChatRepositoryImpl
    let messages: MessageRepositoryImpl
    let contacts: ContactRepositoryImpl
    let avatars: AvatarRepositoryImpl
    let session: ChatSessionRepositoryImpl
}

final class ChatRepositoryTests: XCTestCase {

    private var store: TokenStore!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        store = TestSupport.makeStore()
        store.username = "me"
        store.chatToken = "chat-token"
        store.chatTokenUser = "me"
    }

    override func tearDown() {
        MockURLProtocol.reset()
        store = nil
        super.tearDown()
    }

    private func kit() -> ChatKit {
        let client = TestSupport.chatClient(tokenStore: store)
        let manager = ChatAuthManager(client: client, store: store)
        let authorization = ChatAuthorization(client: client, auth: manager)
        return ChatKit(
            auth: manager,
            chats: ChatRepositoryImpl(auth: authorization, listCache: ChatListCache(), privateCache: PrivateChatCache()),
            messages: MessageRepositoryImpl(auth: authorization, cache: ChatMessagesCache()),
            contacts: ContactRepositoryImpl(auth: authorization),
            avatars: AvatarRepositoryImpl(auth: authorization),
            session: ChatSessionRepositoryImpl(auth: authorization)
        )
    }

    private func bodyJSON(_ request: URLRequest?) -> [String: Any]? {
        guard let data = request?.capturedBody else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func stringBody(_ request: URLRequest?, _ key: String) -> String? {
        bodyJSON(request)?[key] as? String
    }

    private func stringArrayBody(_ request: URLRequest?, _ key: String) -> [String]? {
        bodyJSON(request)?[key] as? [String]
    }

    func testLoadChatsAddsAuthHeader() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data("[]"))
        }

        _ = try await kit().chats.loadChats()

        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/chats")
        XCTAssertEqual(MockURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer chat-token")
    }

    func testTotalUnreadCount() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"count":5}"#))
        }

        let count = try await kit().session.totalUnreadCount()

        XCTAssertEqual(count, 5)
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/chats/unread-count/all")
    }

    func testCreatePrivateChatBody() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"chatUuid":"c-1"}"#))
        }

        _ = try await kit().chats.createPrivateChat(userUuid: "u-2")

        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/chats/private")
        XCTAssertEqual(stringBody(MockURLProtocol.requests.first, "otherUserUuid"), "u-2")
    }

    func testCreateGroupChatBody() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"chatUuid":"c-1","title":"Team"}"#))
        }

        let chat = try await kit().chats.createGroupChat(title: "Team", memberUuids: ["a", "b"])

        XCTAssertEqual(chat.title, "Team")
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/chats/group")
        XCTAssertEqual(stringArrayBody(MockURLProtocol.requests.first, "memberUuids"), ["a", "b"])
    }

    func testLoadChatParticipants() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"[{"userUuid":"u-1","role":"OWNER"}]"#))
        }

        let participants = try await kit().chats.loadChatParticipants(chatUuid: "c-1")

        XCTAssertEqual(participants.count, 1)
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/chats/c-1/participants")
    }

    func testAddGroupParticipants() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 204), Data())
        }

        try await kit().chats.addGroupParticipants(chatUuid: "c-1", memberUuids: ["x"])

        XCTAssertEqual(MockURLProtocol.requests.first?.httpMethod, "POST")
        XCTAssertEqual(stringArrayBody(MockURLProtocol.requests.first, "memberUuids"), ["x"])
    }

    func testLoadContacts() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request),
             TestSupport.data(#"[{"contactUuid":"k","online":false}]"#))
        }

        let contacts = try await kit().contacts.loadContacts()

        XCTAssertEqual(contacts.count, 1)
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/contacts")
    }

    func testAddContactResolvesUsernameThenPosts() async throws {
        MockURLProtocol.handler = { request in
            if request.url?.path == "/api/users/by-username/alice" {
                return (MockURLProtocol.response(for: request), TestSupport.data(#"{"userUuid":"u-9"}"#))
            }
            if request.url?.path == "/api/contacts" {
                return (MockURLProtocol.response(for: request), TestSupport.data(#"{"contactUuid":"k","online":false}"#))
            }
            return (MockURLProtocol.response(for: request, status: 404), Data())
        }

        let contact = try await kit().contacts.addContact(username: "alice")

        XCTAssertEqual(contact.contactUuid, "k")
        let post = MockURLProtocol.requests.first { $0.httpMethod == "POST" }
        XCTAssertEqual(stringBody(post, "contactUserUuid"), "u-9")
    }

    func testLoadMessagesSendsPagingQuery() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"content":[{"messageUuid":"m-1"}]}"#))
        }

        let messages = try await kit().messages.loadMessages(chatUuid: "c-1")

        XCTAssertEqual(messages.count, 1)
        let url = try XCTUnwrap(MockURLProtocol.requests.first?.url)
        XCTAssertEqual(url.path, "/api/messages/c-1")
        XCTAssertEqual(url.query, "page=0&size=50")
    }

    func testSendMessageBody() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"messageUuid":"m-1","text":"hi"}"#))
        }

        _ = try await kit().messages.sendMessage(chatUuid: "c-1", text: "hi")

        XCTAssertEqual(stringBody(MockURLProtocol.requests.first, "text"), "hi")
        XCTAssertEqual(stringBody(MockURLProtocol.requests.first, "messageType"), "TEXT")
    }

    func testMarkMessagesAsReadSendsQuery() async {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 204), Data())
        }

        await kit().messages.markMessagesAsRead(chatUuid: "c-1", upToMessageUuid: "m-9")

        let url = MockURLProtocol.requests.first?.url
        XCTAssertEqual(url?.path, "/api/messages/c-1/read")
        XCTAssertEqual(url?.query, "upToMessageUuid=m-9")
    }

    func testCurrentChatUserAvatar() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"userUuid":"u-1","avatarUrl":"/a.png"}"#))
        }

        let avatar = try await kit().avatars.loadAvatar()

        XCTAssertEqual(avatar, "/a.png")
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/users/me")
    }

    func testUploadAndDeleteAvatar() async throws {
        MockURLProtocol.handler = { request in
            if request.httpMethod == "DELETE" {
                return (MockURLProtocol.response(for: request, status: 204), Data())
            }
            return (MockURLProtocol.response(for: request), TestSupport.data(#"{"avatarUrl":"/api/avatars/x.png"}"#))
        }

        let repo = kit().avatars
        let path = try await repo.uploadAvatar(data: Data([1]), fileName: "a.jpg", mimeType: "image/jpeg")
        XCTAssertEqual(path, "/api/avatars/x.png")
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/users/me/avatar")

        try await repo.deleteAvatar()
        XCTAssertEqual(MockURLProtocol.requests.last?.httpMethod, "DELETE")
    }

    func testUploadChatAvatarReturnsRawPath() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, headers: ["Content-Type": "text/plain"]),
             TestSupport.data("  /api/avatars/group.png\n"))
        }

        let path = try await kit().avatars.uploadChatAvatar(
            chatUuid: "c-1",
            data: Data([1]),
            fileName: "g.jpg",
            mimeType: "image/jpeg"
        )

        XCTAssertEqual(path, "/api/avatars/group.png")
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/chats/c-1/avatar")
    }

    func testReauthenticatesAfter401() async throws {
        var chatsCalls = 0
        MockURLProtocol.handler = { request in
            if request.url?.path == "/api/auth/login" {
                return (MockURLProtocol.response(for: request), TestSupport.data(#"{"token":"new-token"}"#))
            }
            if request.url?.path == "/api/chats" {
                chatsCalls += 1
                if chatsCalls == 1 {
                    return (MockURLProtocol.response(for: request, status: 401), Data())
                }
                return (MockURLProtocol.response(for: request), TestSupport.data("[]"))
            }
            return (MockURLProtocol.response(for: request, status: 404), Data())
        }
        store.password = "pass"

        _ = try await kit().chats.loadChats()

        XCTAssertEqual(chatsCalls, 2)
        XCTAssertEqual(store.chatToken, "new-token")
        XCTAssertTrue(MockURLProtocol.requests.contains { $0.url?.path == "/api/auth/login" })
    }

    func testSendHeartbeatPostsWhenAuthenticated() async {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 204), Data())
        }

        let ok = await kit().session.sendHeartbeat()

        XCTAssertTrue(ok)
        XCTAssertEqual(MockURLProtocol.requests.first?.httpMethod, "POST")
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/presence/heartbeat")
    }

    func testLoadPresenceSendsRepeatedUserUuids() async {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request),
             TestSupport.data(#"[{"userUuid":"u-1","online":true,"lastSeenAt":"2026-09-22T12:00:00Z"}]"#))
        }

        let presence = await kit().contacts.loadPresence(userUuids: ["u-1", "u-2"])

        let url = MockURLProtocol.requests.first?.url
        XCTAssertEqual(url?.path, "/api/presence")
        XCTAssertEqual(url?.query, "userUuids=u-1&userUuids=u-2")
        XCTAssertEqual(presence["u-1"]?.online, true)
    }

    func testLoadPresenceChunksLargeLists() async {
        let uuids = (0..<150).map { "u-\($0)" }
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data("[]"))
        }

        _ = await kit().contacts.loadPresence(userUuids: uuids)

        XCTAssertEqual(MockURLProtocol.requests.count, 2)
    }

    func testLoadPresenceSkipsBlankAndDuplicateUuids() async {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data("[]"))
        }

        _ = await kit().contacts.loadPresence(userUuids: ["u-1", "u-1", "  ", ""])

        XCTAssertEqual(MockURLProtocol.requests.count, 1)
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.query, "userUuids=u-1")
    }

    func testLoadPresenceReturnsEmptyWithoutRequest() async {
        let presence = await kit().contacts.loadPresence(userUuids: [])

        XCTAssertTrue(presence.isEmpty)
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    func testLogoutPostsToAuthLogout() async {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 204), Data())
        }

        let ok = await kit().session.logout()

        XCTAssertTrue(ok)
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/auth/logout")
    }

    func testLogoutStillSucceedsOnNetworkFailure() async {
        MockURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }

        let ok = await kit().session.logout()

        XCTAssertTrue(ok)
    }

    // MARK: - Private chat dedup (OpenPrivateChatUseCase)

    func testFindPrivateChatReturnsExistingWithoutCreating() async throws {
        MockURLProtocol.handler = { request in
            if request.url?.path == "/api/chats" {
                return (MockURLProtocol.response(for: request),
                        TestSupport.data(#"[{"chatUuid":"c-1","chatType":"PRIVATE"}]"#))
            }
            if request.url?.path == "/api/chats/c-1/participants" {
                return (MockURLProtocol.response(for: request),
                        TestSupport.data(#"[{"userUuid":"u-9"}]"#))
            }
            return (MockURLProtocol.response(for: request, status: 500), Data())
        }

        let found = try await kit().chats.findPrivateChatWith(userUuid: "u-9")

        XCTAssertEqual(found?.chatUuid, "c-1")
        XCTAssertFalse(MockURLProtocol.requests.contains { $0.url?.path == "/api/chats/private" })
    }

    func testFindPrivateChatUsesCachedMapping() async throws {
        let kit = kit()
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"chatUuid":"c-1"}"#))
        }
        _ = try await kit.chats.createPrivateChat(userUuid: "u-9")

        MockURLProtocol.reset()
        let found = try await kit.chats.findPrivateChatWith(userUuid: "u-9")

        XCTAssertEqual(found?.chatUuid, "c-1")
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }
}
