import XCTest
@testable import Muzea

/// Удаление аккаунта: chat → makeup → IdP, трактовка 401/404 как успеха
/// (паритет с Android ProfileViewModel/ChatSessionRepository/UserRepository).
final class DeleteAccountTests: XCTestCase {

    private var store: TokenStore!

    private let sampleUser = User(
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
        store.token = "access-token"
        // chat-профиль уже получен: не дергаем /api/users/me в каждом тесте.
        store.chatUserUuid = "u-me"
    }

    override func tearDown() {
        MockURLProtocol.reset()
        store = nil
        super.tearDown()
    }

    private func authorization(_ client: HTTPClient) -> ChatAuthorization {
        ChatAuthorization(client: client, auth: ChatAuthManager(client: client, store: store))
    }

    private func chatSession() -> ChatSessionRepositoryImpl {
        ChatSessionRepositoryImpl(auth: authorization(TestSupport.chatClient(tokenStore: store)))
    }

    private func chatClient() -> HTTPClient {
        TestSupport.chatClient(tokenStore: store)
    }

    private func userRepository() -> UserRepositoryImpl {
        UserRepositoryImpl(client: TestSupport.makeupClient(tokenStore: store))
    }

    private func authRepository() -> AuthRepositoryImpl {
        AuthRepositoryImpl(client: TestSupport.authClient(tokenStore: store), store: store)
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

    func testAuthDeleteAccountSendsDelete() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 200), TestSupport.data(#"{"message":"Account deleted"}"#))
        }

        try await authRepository().deleteAccount()

        XCTAssertEqual(MockURLProtocol.requests.first?.httpMethod, "DELETE")
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/auth/me")
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.host, "auth.muzea.su")
    }

    // MARK: - ProfileViewModel ordering

    @MainActor
    private func makeProfileViewModel() -> ProfileViewModel {
        let client = chatClient()
        let authorization = authorization(client)
        return ProfileViewModel(
            userRepository: userRepository(),
            avatarRepository: AvatarRepositoryImpl(auth: authorization),
            chatSessionRepository: ChatSessionRepositoryImpl(auth: authorization),
            authRepository: authRepository(),
            initialUser: sampleUser,
            initialEmail: "me@example.com"
        )
    }

    @MainActor
    func testDeleteAccountErasesChatThenMakeupThenIdp() async {
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
        XCTAssertEqual(order, ["chat-muzea.su", "api-muzea.su", "auth.muzea.su"])
    }

    @MainActor
    func testDeleteAccountReportsChatFailureButStillErasesRest() async {
        var makeupCalled = false
        var authCalled = false
        MockURLProtocol.handler = { request in
            switch request.url?.host {
            case "chat-muzea.su":
                return (MockURLProtocol.response(for: request, status: 500), Data())
            case "api-muzea.su":
                makeupCalled = true
                return (MockURLProtocol.response(for: request, status: 204), Data())
            case "auth.muzea.su":
                authCalled = true
                return (MockURLProtocol.response(for: request, status: 200), Data())
            default:
                return (MockURLProtocol.response(for: request, status: 404), Data())
            }
        }

        let outcome = await makeProfileViewModel().deleteAccount()

        XCTAssertEqual(outcome, .chatFailed)
        XCTAssertTrue(makeupCalled)
        XCTAssertTrue(authCalled)
    }

    @MainActor
    func testDeleteAccountFailsWhenMakeupRejectsAndSkipsIdp() async {
        var authCalled = false
        MockURLProtocol.handler = { request in
            switch request.url?.host {
            case "chat-muzea.su":
                return (MockURLProtocol.response(for: request, status: 401), Data())
            case "auth.muzea.su":
                authCalled = true
                return (MockURLProtocol.response(for: request, status: 200), Data())
            default:
                return (MockURLProtocol.response(for: request, status: 500), TestSupport.data("boom"))
            }
        }

        let outcome = await makeProfileViewModel().deleteAccount()

        if case .failed = outcome {
            // ok
        } else {
            XCTFail("Ожидался .failed, получено \(outcome)")
        }
        XCTAssertFalse(authCalled)
    }
}
