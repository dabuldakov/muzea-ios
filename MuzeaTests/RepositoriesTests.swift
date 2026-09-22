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

    private func repository() -> NewsRepository {
        NewsRepository(client: TestSupport.makeupClient(tokenStore: store))
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

    private func repository() -> VideoRepository {
        VideoRepository(client: TestSupport.makeupClient(tokenStore: store))
    }

    private let videoJSON = #"{"id":1,"title":"V","description":null,"url":"/api/videos/stream/x.mp4","thumbnailUrl":null,"fileSize":null,"duration":null,"views":0,"likes":null,"uploadedBy":"me","uploadedAt":"2026-01-01T00:00:00"}"#

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

    private func repository() -> ChatRepository {
        let client = TestSupport.chatClient(tokenStore: store)
        return ChatRepository(client: client, auth: ChatAuthManager(client: client, store: store))
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

        _ = try await repository().loadChats()

        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/chats")
        XCTAssertEqual(MockURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer chat-token")
    }

    func testTotalUnreadCount() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"count":5}"#))
        }

        let count = try await repository().totalUnreadCount()

        XCTAssertEqual(count, 5)
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/chats/unread-count/all")
    }

    func testCreatePrivateChatBody() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"chatUuid":"c-1"}"#))
        }

        _ = try await repository().createPrivateChat(userUuid: "u-2")

        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/chats/private")
        XCTAssertEqual(stringBody(MockURLProtocol.requests.first, "otherUserUuid"), "u-2")
    }

    func testCreateGroupChatBody() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"chatUuid":"c-1","title":"Team"}"#))
        }

        let chat = try await repository().createGroupChat(title: "Team", memberUuids: ["a", "b"])

        XCTAssertEqual(chat.title, "Team")
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/chats/group")
        XCTAssertEqual(stringArrayBody(MockURLProtocol.requests.first, "memberUuids"), ["a", "b"])
    }

    func testLoadChatParticipants() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"[{"userUuid":"u-1","role":"OWNER"}]"#))
        }

        let participants = try await repository().loadChatParticipants(chatUuid: "c-1")

        XCTAssertEqual(participants.count, 1)
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/chats/c-1/participants")
    }

    func testAddGroupParticipants() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 204), Data())
        }

        try await repository().addGroupParticipants(chatUuid: "c-1", memberUuids: ["x"])

        XCTAssertEqual(MockURLProtocol.requests.first?.httpMethod, "POST")
        XCTAssertEqual(stringArrayBody(MockURLProtocol.requests.first, "memberUuids"), ["x"])
    }

    func testLoadContacts() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request),
             TestSupport.data(#"[{"contactUuid":"k","isOnline":false}]"#))
        }

        let contacts = try await repository().loadContacts()

        XCTAssertEqual(contacts.count, 1)
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/contacts")
    }

    func testAddContactResolvesUsernameThenPosts() async throws {
        MockURLProtocol.handler = { request in
            if request.url?.path == "/api/users/by-username/alice" {
                return (MockURLProtocol.response(for: request), TestSupport.data(#"{"userUuid":"u-9"}"#))
            }
            if request.url?.path == "/api/contacts" {
                return (MockURLProtocol.response(for: request), TestSupport.data(#"{"contactUuid":"k","isOnline":false}"#))
            }
            return (MockURLProtocol.response(for: request, status: 404), Data())
        }

        let contact = try await repository().addContact(username: "alice")

        XCTAssertEqual(contact.contactUuid, "k")
        let post = MockURLProtocol.requests.first { $0.httpMethod == "POST" }
        XCTAssertEqual(stringBody(post, "contactUserUuid"), "u-9")
    }

    func testLoadMessagesSendsPagingQuery() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"content":[{"messageUuid":"m-1"}]}"#))
        }

        let messages = try await repository().loadMessages(chatUuid: "c-1")

        XCTAssertEqual(messages.count, 1)
        let url = try XCTUnwrap(MockURLProtocol.requests.first?.url)
        XCTAssertEqual(url.path, "/api/messages/c-1")
        XCTAssertEqual(url.query, "page=0&size=50")
    }

    func testSendMessageBody() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"messageUuid":"m-1","text":"hi"}"#))
        }

        _ = try await repository().sendMessage(chatUuid: "c-1", text: "hi")

        XCTAssertEqual(stringBody(MockURLProtocol.requests.first, "text"), "hi")
        XCTAssertEqual(stringBody(MockURLProtocol.requests.first, "messageType"), "TEXT")
    }

    func testMarkMessagesAsReadSendsQuery() async {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 204), Data())
        }

        await repository().markMessagesAsRead(chatUuid: "c-1", upToMessageUuid: "m-9")

        let url = MockURLProtocol.requests.first?.url
        XCTAssertEqual(url?.path, "/api/messages/c-1/read")
        XCTAssertEqual(url?.query, "upToMessageUuid=m-9")
    }

    func testCurrentChatUser() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"userUuid":"u-1","avatarUrl":"/a.png"}"#))
        }

        let user = try await repository().currentChatUser()

        XCTAssertEqual(user.avatarUrl, "/a.png")
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/users/me")
    }

    func testUploadAndDeleteAvatar() async throws {
        MockURLProtocol.handler = { request in
            if request.httpMethod == "DELETE" {
                return (MockURLProtocol.response(for: request, status: 204), Data())
            }
            return (MockURLProtocol.response(for: request), TestSupport.data(#"{"avatarUrl":"/api/avatars/x.png"}"#))
        }

        let repo = repository()
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

        let path = try await repository().uploadChatAvatar(
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

        _ = try await repository().loadChats()

        XCTAssertEqual(chatsCalls, 2)
        XCTAssertEqual(store.chatToken, "new-token")
        XCTAssertTrue(MockURLProtocol.requests.contains { $0.url?.path == "/api/auth/login" })
    }
}