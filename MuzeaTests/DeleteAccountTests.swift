import XCTest
@testable import Muzea

/// Удаление аккаунта: порядок чат → основной сервер и трактовка 401/404 как успеха
/// (паритет с Android ProfileViewModel/ChatSessionRepository/UserRepository).
final class DeleteAccountTests: XCTestCase {

    private var store: TokenStore!

    private let sampleUser = UserResponse(
        id: 7,
        userName: "me",
        email: "me@example.com",
        fullName: "Me",
        avatarUrl: nil,
        role: "USER",
        createdAt: nil,
        enabled: true
    )

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

    private func chatSession() -> ChatSessionRepositoryImpl {
        let client = TestSupport.chatClient(tokenStore: store)
        let authorization = ChatAuthorization(
            client: client,
            auth: ChatAuthManager(client: client, store: store)
        )
        return ChatSessionRepositoryImpl(auth: authorization)
    }

    private func userRepository() -> UserRepositoryImpl {
        UserRepositoryImpl(client: TestSupport.makeupClient(tokenStore: store))
    }

    func testChatDeleteAccountSendsDelete() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 204), Data())
        }

        try await chatSession().deleteAccount()

        XCTAssertEqual(MockURLProtocol.requests.first?.httpMethod, "DELETE")
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/users/me")
    }

    func testChatDeleteAccountTreats401AsSuccess() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 401), Data())
        }

        try await chatSession().deleteAccount()

        // Без повторной авторизации: 401 после удаления — нормальный ответ сервера.
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
    }

    func testChatDeleteAccountTreats404AsSuccess() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 404), Data())
        }

        try await chatSession().deleteAccount()
    }

    func testChatDeleteAccountThrowsOnServerError() async {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 500), TestSupport.data("boom"))
        }

        do {
            try await chatSession().deleteAccount()
            XCTFail("Ожидалась ошибка сервера")
        } catch {
            // ok
        }
    }

    func testMainDeleteAccountTreats404AsSuccess() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 404), Data())
        }

        try await userRepository().deleteAccount(id: 42)

        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/users/42")
    }

    func testMainDeleteAccountThrowsOnServerError() async {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 500), TestSupport.data("boom"))
        }

        do {
            try await userRepository().deleteAccount(id: 42)
            XCTFail("Ожидалась ошибка сервера")
        } catch APIError.server(let code, _) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }

    // MARK: - ProfileViewModel ordering

    @MainActor
    private func makeProfileViewModel() -> ProfileViewModel {
        let chatClient = TestSupport.chatClient(tokenStore: store)
        let authorization = ChatAuthorization(
            client: chatClient,
            auth: ChatAuthManager(client: chatClient, store: store)
        )
        return ProfileViewModel(
            userRepository: userRepository(),
            avatarRepository: AvatarRepositoryImpl(auth: authorization),
            chatSessionRepository: ChatSessionRepositoryImpl(auth: authorization),
            initialUser: sampleUser
        )
    }

    @MainActor
    func testDeleteAccountErasesChatBeforeMain() async {
        var order: [String] = []
        MockURLProtocol.handler = { request in
            let host = request.url?.host ?? ""
            order.append(host)
            if host == "chat-muzea.su" {
                return (MockURLProtocol.response(for: request, status: 401), Data())
            }
            return (MockURLProtocol.response(for: request, status: 204), Data())
        }

        let outcome = await makeProfileViewModel().deleteAccount()

        XCTAssertEqual(outcome, .deleted)
        XCTAssertEqual(order, ["chat-muzea.su", "api-muzea.su"])
    }

    @MainActor
    func testDeleteAccountReportsChatFailureButStillErasesMain() async {
        var mainDeleteCalled = false
        MockURLProtocol.handler = { request in
            if request.url?.host == "chat-muzea.su" {
                return (MockURLProtocol.response(for: request, status: 500), Data())
            }
            mainDeleteCalled = true
            return (MockURLProtocol.response(for: request, status: 204), Data())
        }

        let outcome = await makeProfileViewModel().deleteAccount()

        XCTAssertEqual(outcome, .chatFailed)
        XCTAssertTrue(mainDeleteCalled)
    }

    @MainActor
    func testDeleteAccountFailsWhenMainServerRejects() async {
        MockURLProtocol.handler = { request in
            if request.url?.host == "chat-muzea.su" {
                return (MockURLProtocol.response(for: request, status: 401), Data())
            }
            return (MockURLProtocol.response(for: request, status: 500), TestSupport.data("boom"))
        }

        let outcome = await makeProfileViewModel().deleteAccount()

        if case .failed = outcome {
            // ok
        } else {
            XCTFail("Ожидался .failed, получено \(outcome)")
        }
    }
}
