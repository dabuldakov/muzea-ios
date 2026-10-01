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
        let store = TestSupport.makeStore(defaults: defaults)
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
        let store = TestSupport.makeStore(defaults: defaults)
        XCTAssertFalse(store.isLoggedIn)

        store.token = "t"
        XCTAssertFalse(store.isLoggedIn)

        store.username = "alice"
        XCTAssertTrue(store.isLoggedIn)
    }

    func testDeviceIdIsStable() {
        let store = TestSupport.makeStore(defaults: defaults)
        let first = store.deviceId
        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(first, store.deviceId)
    }

    func testDeviceTypeIsIOS() {
        XCTAssertEqual(TestSupport.makeStore(defaults: defaults).deviceType, "IOS")
    }

    func testPasswordIsNotStoredInUserDefaults() {
        let passwords = InMemoryPasswordStore()
        let store = TestSupport.makeStore(defaults: defaults, passwords: passwords)
        store.password = "secret"

        XCTAssertEqual(store.password, "secret")
        XCTAssertNil(defaults.string(forKey: "password"))
        XCTAssertEqual(passwords.password, "secret")
    }

    func testMigratesLegacyPlaintextPasswordToSecureStore() {
        defaults.set("legacy", forKey: "password")
        let passwords = InMemoryPasswordStore()

        let store = TokenStore(defaults: defaults, passwordStore: passwords)

        XCTAssertEqual(store.password, "legacy")
        XCTAssertEqual(passwords.password, "legacy")
        XCTAssertNil(defaults.string(forKey: "password"))
    }

    func testClearRemovesSessionKeysAndPassword() {
        let store = TestSupport.makeStore(defaults: defaults)
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
        // Как и на Android, logout очищает и пароль из защищённого хранилища.
        XCTAssertNil(store.password)
    }

    func testClearAllRemovesEveryLocalKey() {
        let store = TestSupport.makeStore(defaults: defaults)
        store.token = "t"
        store.username = "alice"
        store.email = "alice@mail.com"
        store.password = "secret"
        store.chatToken = "ct"
        store.chatTokenUser = "alice"
        store.fcmToken = "fcm"
        store.registeredFcmToken = "fcm"
        _ = store.deviceId

        store.clearAll()

        XCTAssertNil(store.token)
        XCTAssertNil(store.username)
        XCTAssertNil(store.email)
        XCTAssertNil(store.password)
        XCTAssertNil(store.chatToken)
        XCTAssertNil(store.chatTokenUser)
        XCTAssertNil(store.fcmToken)
        XCTAssertNil(store.registeredFcmToken)
        XCTAssertNil(defaults.string(forKey: "device_id"))
    }
}
