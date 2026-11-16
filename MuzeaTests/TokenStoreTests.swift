import XCTest
@testable import Muzea

final class TokenStoreTests: XCTestCase {

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "muzea-token-tests-\(UUID().uuidString)")!
    }

    func testTokensRoundTripInSecureStore() {
        let store = TokenStore(defaults: isolatedDefaults(), tokens: InMemoryTokenStore())

        store.token = "access"
        store.refreshToken = "refresh"

        XCTAssertEqual(store.token, "access")
        XCTAssertEqual(store.refreshToken, "refresh")
        XCTAssertTrue(store.isLoggedIn)
    }

    func testClearSessionRemovesTokensAndProfileButKeepsDevice() {
        let store = TokenStore(defaults: isolatedDefaults(), tokens: InMemoryTokenStore())
        store.token = "access"
        store.refreshToken = "refresh"
        store.username = "alice"
        store.email = "a@b.c"
        store.chatUserUuid = "u-1"
        store.fcmToken = "fcm"
        store.registeredFcmToken = "fcm"
        let device = store.deviceId

        store.clearSession()

        XCTAssertNil(store.token)
        XCTAssertNil(store.refreshToken)
        XCTAssertNil(store.username)
        XCTAssertNil(store.email)
        XCTAssertNil(store.chatUserUuid)
        XCTAssertNil(store.registeredFcmToken)
        XCTAssertEqual(store.fcmToken, "fcm")
        XCTAssertEqual(store.deviceId, device)
        XCTAssertFalse(store.isLoggedIn)
    }

    func testClearAllRemovesDeviceAndEverythingElse() {
        let store = TokenStore(defaults: isolatedDefaults(), tokens: InMemoryTokenStore())
        store.token = "access"
        store.username = "alice"
        let device = store.deviceId

        store.clearAll()

        XCTAssertNil(store.token)
        XCTAssertNil(store.username)
        XCTAssertNotEqual(store.deviceId, device)
        XCTAssertFalse(store.isLoggedIn)
    }

    func testMigratesLegacyAuthTokenAndPurgesLegacySecrets() {
        let defaults = isolatedDefaults()
        defaults.set("legacy-access", forKey: "auth_token")
        defaults.set("old-password", forKey: "password")
        defaults.set("old-chat-token", forKey: "chat_token")
        defaults.set("old-chat-user", forKey: "chat_token_user")
        let tokens = InMemoryTokenStore()

        let store = TokenStore(defaults: defaults, tokens: tokens)

        XCTAssertEqual(store.token, "legacy-access")
        XCTAssertEqual(tokens.accessToken, "legacy-access")
        XCTAssertNil(defaults.string(forKey: "auth_token"))
        XCTAssertNil(defaults.string(forKey: "password"))
        XCTAssertNil(defaults.string(forKey: "chat_token"))
        XCTAssertNil(defaults.string(forKey: "chat_token_user"))
    }

    func testKeychainStoreRoundTripAndClear() {
        let store = KeychainTokenStore(service: "muzea-tests-\(UUID().uuidString)")
        store.accessToken = "a"
        store.refreshToken = "r"

        XCTAssertEqual(store.accessToken, "a")
        XCTAssertEqual(store.refreshToken, "r")

        store.clear()
        XCTAssertNil(store.accessToken)
        XCTAssertNil(store.refreshToken)
    }
}
