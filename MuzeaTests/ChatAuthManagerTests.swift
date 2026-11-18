import XCTest
@testable import Muzea

/// Chat больше не логинится отдельно: используется единый access-токен IdP.
/// Проверяем проверку сессии, однократное получение chat-профиля и FCM.
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

    func testReturnsFalseWithoutTokenAndMakesNoRequest() async {
        let auth = manager()

        let result = await auth.ensureAuthenticated()

        XCTAssertFalse(result)
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    func testFetchesChatProfileOnce() async {
        store.token = "access"
        MockURLProtocol.handler = { request in
            if request.url?.path == "/api/users/me" {
                return (MockURLProtocol.response(for: request), TestSupport.data(#"{"userUuid":"u-1","username":"alice"}"#))
            }
            return (MockURLProtocol.response(for: request, status: 404), Data())
        }

        let auth = manager()
        let first = await auth.ensureAuthenticated()
        let callsAfterFirst = MockURLProtocol.requests.count
        let second = await auth.ensureAuthenticated()

        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertEqual(store.chatUserUuid, "u-1")
        XCTAssertEqual(callsAfterFirst, 1)
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
    }

    func testDoesNotFailWhenProfileFetchFails() async {
        store.token = "access"
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 500), TestSupport.data("boom"))
        }

        let auth = manager()
        let result = await auth.ensureAuthenticated()

        XCTAssertTrue(result)
        XCTAssertNil(store.chatUserUuid)
    }

    func testRegistersFcmTokenOnceWithDeviceId() async {
        store.token = "access"
        store.chatUserUuid = "u-1"
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
        let request = MockURLProtocol.requests.first { $0.url?.path == "/api/users/me/fcm-token" }
        XCTAssertEqual(request?.httpMethod, "PUT")
        let body = request?.capturedBody
        let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        XCTAssertEqual(json?["token"] as? String, "fcm-1")
        XCTAssertEqual(json?["deviceId"] as? String, store.deviceId)
        XCTAssertNil(json?["deviceType"])

        MockURLProtocol.reset()
        _ = await auth.ensureAuthenticated()
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    func testRetriesFcmRegistrationAfterFailure() async {
        store.token = "access"
        store.chatUserUuid = "u-1"
        store.fcmToken = "fcm-1"
        var calls = 0
        MockURLProtocol.handler = { request in
            calls += 1
            if calls == 1 {
                return (MockURLProtocol.response(for: request, status: 500), Data())
            }
            return (MockURLProtocol.response(for: request, status: 204), Data())
        }

        let auth = manager()
        _ = await auth.ensureAuthenticated()
        XCTAssertNil(store.registeredFcmToken)

        _ = await auth.ensureAuthenticated()
        XCTAssertEqual(store.registeredFcmToken, "fcm-1")
        XCTAssertEqual(calls, 2)
    }

}
