import XCTest
@testable import Muzea

/// Удаление аккаунта: порядок чат → основной сервер и трактовка 401/404 как успеха
/// (паритет с Android ProfileViewModel/UserRepository/ChatRepository).
final class DeleteAccountTests: XCTestCase {

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

    private func chatRepository() -> ChatRepository {
        let client = TestSupport.chatClient(tokenStore: store)
        return ChatRepository(client: client, auth: ChatAuthManager(client: client, store: store))
    }

    private func authRepository() -> AuthRepository {
        AuthRepository(client: TestSupport.makeupClient(tokenStore: store), store: store)
    }

    func testChatDeleteAccountSendsDelete() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 204), Data())
        }

        try await chatRepository().deleteAccount()

        XCTAssertEqual(MockURLProtocol.requests.first?.httpMethod, "DELETE")
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/users/me")
    }

    func testChatDeleteAccountTreats401AsSuccess() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 401), Data())
        }

        try await chatRepository().deleteAccount()

        // Без повторной авторизации: 401 после удаления — нормальный ответ сервера.
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
    }

    func testChatDeleteAccountTreats404AsSuccess() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 404), Data())
        }

        try await chatRepository().deleteAccount()
    }

    func testChatDeleteAccountThrowsOnServerError() async {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 500), TestSupport.data("boom"))
        }

        do {
            try await chatRepository().deleteAccount()
            XCTFail("Ожидалась ошибка сервера")
        } catch {
            // ok
        }
    }

    func testMainDeleteAccountTreats404AsSuccess() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 404), Data())
        }

        try await authRepository().deleteAccount(id: 42)

        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/api/users/42")
    }

    func testMainDeleteAccountThrowsOnServerError() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 500), TestSupport.data("boom"))
        }

        do {
            try await authRepository().deleteAccount(id: 42)
            XCTFail("Ожидалась ошибка сервера")
        } catch APIError.server(let code, _) {
            XCTAssertEqual(code, 500)
        }
    }

    // MARK: - ProfileViewModel ordering

    @MainActor
    private func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(authRepository: authRepository(), chatRepository: chatRepository())
    }

    @MainActor
    private func seedUser(_ viewModel: ProfileViewModel) {
        viewModel.user = UserResponse(
            id: 7,
            userName: "me",
            email: "me@example.com",
            fullName: "Me",
            avatarUrl: nil,
            role: "USER",
            createdAt: nil,
            enabled: true
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

        let viewModel = makeProfileViewModel()
        seedUser(viewModel)
        let outcome = await viewModel.deleteAccount()

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

        let viewModel = makeProfileViewModel()
        seedUser(viewModel)
        let outcome = await viewModel.deleteAccount()

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

        let viewModel = makeProfileViewModel()
        seedUser(viewModel)
        let outcome = await viewModel.deleteAccount()

        if case .failed = outcome {
            // ok
        } else {
            XCTFail("Ожидался .failed, получено \(outcome)")
        }
    }
}
