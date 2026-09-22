import XCTest
@testable import Muzea

/// Зеркалит Android `ChatAuthManagerTest`.
final class ChatAuthManagerTests: XCTestCase {

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

    private func manager() -> ChatAuthManager {
        ChatAuthManager(client: TestSupport.chatClient(tokenStore: store), store: store)
    }

    private func isLogin(_ request: URLRequest) -> Bool {
        request.url?.path == "/api/auth/login" && request.httpMethod == "POST"
    }

    private func isRegister(_ request: URLRequest) -> Bool {
        request.url?.path == "/api/auth/register" && request.httpMethod == "POST"
    }

    private func authJSON(_ token: String) -> Data {
        TestSupport.data(#"{"token":"\#(token)"}"#)
    }

    func testReturnsTrueWhenTokenBelongsToCurrentUser() async {
        store.username = "alice"
        store.chatToken = "existing-token"
        store.chatTokenUser = "alice"

        let result = await manager().ensureAuthenticated()

        XCTAssertTrue(result)
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    func testClearsTokenBelongingToAnotherUserAndRelogs() async {
        store.username = "bob"
        store.chatToken = "token-for-alice"
        store.chatTokenUser = "alice"
        store.password = "pass"
        store.email = "bob@mail.com"
        MockURLProtocol.handler = { [self] request in
            if isLogin(request) {
                return (MockURLProtocol.response(for: request), authJSON("token-1"))
            }
            return (MockURLProtocol.response(for: request, status: 404), Data())
        }

        let result = await manager().ensureAuthenticated()

        XCTAssertTrue(result)
        XCTAssertEqual(store.chatToken, "token-1")
        XCTAssertEqual(store.chatTokenUser, "bob")
        XCTAssertTrue(MockURLProtocol.requests.contains(where: isLogin))
    }

    func testClearsTokenWhenOwnerUnknownButUserPresent() async {
        store.username = "bob"
        store.chatToken = "orphan-token"
        store.chatTokenUser = nil
        store.password = "pass"
        MockURLProtocol.handler = { [self] request in
            if isLogin(request) {
                return (MockURLProtocol.response(for: request), authJSON("fresh"))
            }
            return (MockURLProtocol.response(for: request, status: 404), Data())
        }

        let result = await manager().ensureAuthenticated()

        XCTAssertTrue(result)
        XCTAssertEqual(store.chatToken, "fresh")
    }

    func testFallsBackToRegistrationWhenLoginFails() async {
        store.username = "carol"
        store.password = "secret"
        store.email = "carol@mail.com"
        MockURLProtocol.handler = { [self] request in
            if isLogin(request) {
                return (MockURLProtocol.response(for: request, status: 401), Data())
            }
            if isRegister(request) {
                return (MockURLProtocol.response(for: request), authJSON("register-token"))
            }
            return (MockURLProtocol.response(for: request, status: 404), Data())
        }

        let result = await manager().ensureAuthenticated()

        XCTAssertTrue(result)
        XCTAssertEqual(store.chatToken, "register-token")
        XCTAssertEqual(store.chatTokenUser, "carol")

        let registerRequest = MockURLProtocol.requests.first(where: isRegister)
        let body = try? XCTUnwrap(registerRequest?.capturedBody)
        let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] }
        XCTAssertEqual(json?["username"], "carol")
        XCTAssertEqual(json?["email"], "carol@mail.com")
    }

    func testRegistersWithGeneratedEmailWhenMissing() async {
        store.username = "dave"
        store.password = "secret"
        MockURLProtocol.handler = { [self] request in
            if isLogin(request) {
                return (MockURLProtocol.response(for: request, status: 401), Data())
            }
            if isRegister(request) {
                return (MockURLProtocol.response(for: request), authJSON("t"))
            }
            return (MockURLProtocol.response(for: request, status: 404), Data())
        }

        _ = await manager().ensureAuthenticated()

        let registerRequest = MockURLProtocol.requests.first(where: isRegister)
        let body = try? XCTUnwrap(registerRequest?.capturedBody)
        let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] }
        XCTAssertEqual(json?["email"], "dave@example.com")
    }

    func testReturnsFalseWithoutCredentials() async {
        let auth = manager()

        let result = await auth.ensureAuthenticated()

        XCTAssertFalse(result)
        XCTAssertNotNil(auth.lastFailureMessage)
        XCTAssertTrue(auth.lastFailureMessage?.contains("log in") == true)
    }

    func testReportsConflictWhenUsernameTakenWithOtherPassword() async {
        store.username = "erin"
        store.password = "secret"
        store.email = "erin@mail.com"
        MockURLProtocol.handler = { [self] request in
            if isLogin(request) {
                return (MockURLProtocol.response(for: request, status: 401), Data())
            }
            if isRegister(request) {
                return (MockURLProtocol.response(for: request, status: 409), Data())
            }
            return (MockURLProtocol.response(for: request, status: 404), Data())
        }

        let auth = manager()
        let result = await auth.ensureAuthenticated()

        XCTAssertFalse(result)
        XCTAssertNil(store.chatToken)
        XCTAssertTrue(auth.lastFailureMessage?.contains("already exists") == true)
        XCTAssertTrue(auth.lastFailureMessage?.contains("erin") == true)
    }

    func testReportsNetworkFailure() async {
        store.username = "frank"
        store.password = "secret"
        MockURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }

        let auth = manager()
        let result = await auth.ensureAuthenticated()

        XCTAssertFalse(result)
        XCTAssertEqual(auth.lastFailureMessage, "Cannot reach the chat server.")
    }

    func testInvalidateClearsStoredToken() {
        store.chatToken = "x"
        store.chatTokenUser = "y"
        let auth = manager()

        auth.invalidate()

        XCTAssertNil(store.chatToken)
        XCTAssertNil(store.chatTokenUser)
    }

    func testRegistersFcmTokenOnce() async {
        store.username = "me"
        store.chatToken = "t"
        store.chatTokenUser = "me"
        store.fcmToken = "fcm-1"
        MockURLProtocol.handler = { request in
            if request.url?.path == "/api/users/me/fcm-token" {
                return (MockURLProtocol.response(for: request, status: 204), Data())
            }
            return (MockURLProtocol.response(for: request, status: 404), Data())
        }

        let auth = manager()
        _ = await auth.ensureAuthenticated()
        XCTAssertEqual(store.registeredFcmToken, "fcm-1")

        MockURLProtocol.reset()
        _ = await auth.ensureAuthenticated()
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }
}