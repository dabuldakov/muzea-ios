import XCTest
@testable import Muzea

final class TokenStoreTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "muzea-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testStoresAndReadsAllKeys() {
        let store = TokenStore(defaults: defaults)
        store.token = "t"
        store.username = "alice"
        store.email = "alice@mail.com"
        store.password = "secret"
        store.chatToken = "ct"
        store.chatTokenUser = "alice"
        store.fcmToken = "fcm"
        store.registeredFcmToken = "fcm"

        XCTAssertEqual(store.token, "t")
        XCTAssertEqual(store.username, "alice")
        XCTAssertEqual(store.email, "alice@mail.com")
        XCTAssertEqual(store.password, "secret")
        XCTAssertEqual(store.chatToken, "ct")
        XCTAssertEqual(store.chatTokenUser, "alice")
        XCTAssertEqual(store.fcmToken, "fcm")
        XCTAssertEqual(store.registeredFcmToken, "fcm")
    }

    func testIsLoggedInRequiresTokenAndUsername() {
        let store = TokenStore(defaults: defaults)
        XCTAssertFalse(store.isLoggedIn)

        store.token = "t"
        XCTAssertFalse(store.isLoggedIn)

        store.username = "alice"
        XCTAssertTrue(store.isLoggedIn)
    }

    func testDeviceIdIsStable() {
        let store = TokenStore(defaults: defaults)
        let first = store.deviceId
        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(first, store.deviceId)
    }

    func testDeviceTypeIsIOS() {
        XCTAssertEqual(TokenStore(defaults: defaults).deviceType, "IOS")
    }

    func testClearRemovesSessionKeys() {
        let store = TokenStore(defaults: defaults)
        store.token = "t"
        store.username = "alice"
        store.chatToken = "ct"
        store.chatTokenUser = "alice"
        store.password = "secret"

        store.clear()

        XCTAssertNil(store.token)
        XCTAssertNil(store.username)
        XCTAssertNil(store.chatToken)
        XCTAssertNil(store.chatTokenUser)
        // Как и на Android, пароль/email при logout не удаляются.
        XCTAssertEqual(store.password, "secret")
    }
}