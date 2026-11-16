import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import Muzea

/// Контракт auth-service: OTP-регистрация/вход, сохранение пары токенов,
/// профиль, logout и удаление аккаунта.
final class AuthServiceTests: XCTestCase {

    private var store: TokenStore!

    private let tokenJSON = #"""
    {
      "accessToken":"access-1",
      "refreshToken":"refresh-1",
      "tokenType":"Bearer",
      "expiresIn":900,
      "user":{"id":"u-1","email":"a@b.c","username":"alice","displayName":"Alice","emailVerified":true}
    }
    """#

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

    private func repository() -> AuthRepositoryImpl {
        AuthRepositoryImpl(client: TestSupport.authClient(tokenStore: store), store: store)
    }

    private func body(_ request: URLRequest?) -> [String: Any]? {
        guard let data = request?.capturedBody else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    func testRegisterSendsFieldsWithoutAuth() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"message":"Verification code sent"}"#))
        }

        try await repository().register(email: "a@b.c", username: "alice", displayName: "Alice")

        let request = try XCTUnwrap(MockURLProtocol.requests.first)
        XCTAssertEqual(request.url?.path, "/auth/register")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(body(request)?["email"] as? String, "a@b.c")
        XCTAssertEqual(body(request)?["username"] as? String, "alice")
        XCTAssertEqual(body(request)?["displayName"] as? String, "Alice")
    }

    func testVerifyEmailPersistsTokens() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(self.tokenJSON))
        }

        try await repository().verifyEmail(email: "a@b.c", code: "123456")

        let request = try XCTUnwrap(MockURLProtocol.requests.first)
        XCTAssertEqual(request.url?.path, "/auth/verify-email")
        XCTAssertEqual(body(request)?["code"] as? String, "123456")
        XCTAssertEqual(body(request)?["deviceId"] as? String, store.deviceId)
        XCTAssertEqual(store.token, "access-1")
        XCTAssertEqual(store.refreshToken, "refresh-1")
        XCTAssertEqual(store.username, "alice")
        XCTAssertEqual(store.email, "a@b.c")
    }

    func testRequestLoginCode() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"message":"If the account exists, a code has been sent"}"#))
        }

        try await repository().requestLoginCode(email: "a@b.c")

        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/auth/otp/request")
        XCTAssertEqual(body(MockURLProtocol.requests.first)?["email"] as? String, "a@b.c")
    }

    func testVerifyLoginCodePersistsTokens() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(self.tokenJSON))
        }

        try await repository().verifyLoginCode(email: "a@b.c", code: "000000")

        let request = try XCTUnwrap(MockURLProtocol.requests.first)
        XCTAssertEqual(request.url?.path, "/auth/otp/verify")
        XCTAssertEqual(body(request)?["code"] as? String, "000000")
        XCTAssertEqual(store.token, "access-1")
        XCTAssertEqual(store.refreshToken, "refresh-1")
    }

    func testResendVerification() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"message":"ok"}"#))
        }

        try await repository().resendVerification(email: "a@b.c")

        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/auth/resend-verification")
    }

    func testCurrentUserUsesBearer() async throws {
        store.token = "access-1"
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request),
             TestSupport.data(#"{"id":"u-1","email":"a@b.c","username":"alice","displayName":"Alice","emailVerified":true}"#))
        }

        let user = try await repository().currentUser()

        XCTAssertEqual(user.email, "a@b.c")
        XCTAssertEqual(user.username, "alice")
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/auth/me")
        XCTAssertEqual(MockURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer access-1")
    }

    func testDeleteAccount() async throws {
        store.token = "access-1"
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 200), TestSupport.data(#"{"message":"Account deleted"}"#))
        }

        try await repository().deleteAccount()

        XCTAssertEqual(MockURLProtocol.requests.first?.url?.path, "/auth/me")
        XCTAssertEqual(MockURLProtocol.requests.first?.httpMethod, "DELETE")
    }

    func testLogoutClearsLocallyThenRevokesRefresh() async {
        store.token = "access-1"
        store.refreshToken = "refresh-1"
        store.username = "alice"
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"message":"Logged out"}"#))
        }

        await repository().logout()

        XCTAssertNil(store.token)
        XCTAssertNil(store.refreshToken)
        XCTAssertNil(store.username)
        let request = MockURLProtocol.requests.first
        XCTAssertEqual(request?.url?.path, "/auth/logout")
        XCTAssertNil(request?.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(body(request)?["refreshToken"] as? String, "refresh-1")
    }

    func testLogoutClearsEvenWhenNetworkFails() async {
        store.token = "access-1"
        store.refreshToken = "refresh-1"
        MockURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }

        await repository().logout()

        XCTAssertNil(store.token)
        XCTAssertNil(store.refreshToken)
    }

    func testIsLoggedInReflectsAccessToken() {
        XCTAssertFalse(repository().isLoggedIn)
        store.token = "access-1"
        XCTAssertTrue(repository().isLoggedIn)
    }
}
