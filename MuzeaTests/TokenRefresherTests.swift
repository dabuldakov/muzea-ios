import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import Muzea

/// Refresh-токен одноразовый: повторный refresh отзывает family. Проверяем
/// single-flight, защиту от повторного refresh и очистку сессии при ошибке.
final class TokenRefresherTests: XCTestCase {

    private var store: TokenStore!

    private let tokenJSON = #"""
    {
      "accessToken":"new-access",
      "refreshToken":"new-refresh",
      "tokenType":"Bearer",
      "expiresIn":900,
      "user":{"id":"u-1","email":"a@b.c","username":"alice","emailVerified":true}
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

    private func refresher() -> TokenRefresher {
        TokenRefresher(client: TestSupport.authClient(tokenStore: store), store: store)
    }

    private func body(_ request: URLRequest?) -> [String: Any]? {
        guard let data = request?.capturedBody else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    func testRefreshPersistsNewTokens() async {
        store.token = "old-access"
        store.refreshToken = "old-refresh"
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(self.tokenJSON))
        }

        let ok = await refresher().refresh(failedToken: "old-access")

        XCTAssertTrue(ok)
        XCTAssertEqual(store.token, "new-access")
        XCTAssertEqual(store.refreshToken, "new-refresh")
        let request = MockURLProtocol.requests.first
        XCTAssertEqual(request?.url?.path, "/auth/token/refresh")
        XCTAssertNil(request?.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(body(request)?["refreshToken"] as? String, "old-refresh")
        XCTAssertEqual(body(request)?["deviceId"] as? String, store.deviceId)
    }

    func testSkipsWhenTokenAlreadyRefreshed() async {
        store.token = "new-access"
        store.refreshToken = "new-refresh"

        let ok = await refresher().refresh(failedToken: "old-access")

        XCTAssertTrue(ok)
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    func testNilFailedTokenDoesNothing() async {
        store.token = "access"
        store.refreshToken = "refresh"

        let ok = await refresher().refresh(failedToken: nil)

        XCTAssertFalse(ok)
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    func testConcurrentCallsShareOneRequest() async {
        store.token = "old-access"
        store.refreshToken = "old-refresh"
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(self.tokenJSON))
        }
        let refresher = refresher()

        async let first = refresher.refresh(failedToken: "old-access")
        async let second = refresher.refresh(failedToken: "old-access")
        let (a, b) = await (first, second)

        XCTAssertTrue(a)
        XCTAssertTrue(b)
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
        XCTAssertEqual(store.token, "new-access")
    }

    func testFailureClearsSessionAndCallsExpiredHandler() async {
        store.token = "old-access"
        store.refreshToken = "old-refresh"
        store.username = "alice"
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 401), Data())
        }
        let expired = expectation(description: "session expired")
        let refresher = refresher()
        await refresher.setExpiredHandler { expired.fulfill() }

        let ok = await refresher.refresh(failedToken: "old-access")
        await fulfillment(of: [expired], timeout: 1)

        XCTAssertFalse(ok)
        XCTAssertNil(store.token)
        XCTAssertNil(store.refreshToken)
        XCTAssertNil(store.username)
    }

    func testBadRequestExpiresSession() async {
        store.token = "old-access"
        store.refreshToken = "old-refresh"
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 400), Data())
        }
        let expired = expectation(description: "expired")
        let refresher = refresher()
        await refresher.setExpiredHandler { expired.fulfill() }

        let ok = await refresher.refresh(failedToken: "old-access")
        await fulfillment(of: [expired], timeout: 1)

        XCTAssertFalse(ok)
        XCTAssertNil(store.token)
    }

    func testTransportErrorKeepsSession() async {
        store.token = "old-access"
        store.refreshToken = "old-refresh"
        MockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let expired = expectation(description: "not expired")
        expired.isInverted = true
        let refresher = refresher()
        await refresher.setExpiredHandler { expired.fulfill() }

        let ok = await refresher.refresh(failedToken: "old-access")
        await fulfillment(of: [expired], timeout: 0.3)

        XCTAssertFalse(ok)
        XCTAssertEqual(store.token, "old-access")
        XCTAssertEqual(store.refreshToken, "old-refresh")
    }

    func testServerErrorKeepsSession() async {
        store.token = "old-access"
        store.refreshToken = "old-refresh"
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 503), Data())
        }
        let expired = expectation(description: "not expired")
        expired.isInverted = true
        let refresher = refresher()
        await refresher.setExpiredHandler { expired.fulfill() }

        let ok = await refresher.refresh(failedToken: "old-access")
        await fulfillment(of: [expired], timeout: 0.3)

        XCTAssertFalse(ok)
        XCTAssertEqual(store.token, "old-access")
        XCTAssertEqual(store.refreshToken, "old-refresh")
    }

    func testMissingRefreshTokenDoesNotCallNetwork() async {
        store.token = "old-access"
        store.refreshToken = nil
        let expired = expectation(description: "session expired")
        let refresher = refresher()
        await refresher.setExpiredHandler { expired.fulfill() }

        let ok = await refresher.refresh(failedToken: "old-access")
        await fulfillment(of: [expired], timeout: 1)

        XCTAssertFalse(ok)
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
        XCTAssertNil(store.token)
    }
}
