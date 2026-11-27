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

    func testFallsBackToMemoryWhenSecureStoreReadFails() {
        let tokens = TestSupport.UnreliableTokenStore()
        let store = TokenStore(defaults: isolatedDefaults(), tokens: tokens)
        store.refreshToken = "refresh"
        store.token = "access"

        // Keychain временно недоступен: значения уже в памяти процесса.
        tokens.failReads = true

        XCTAssertEqual(store.token, "access")
        XCTAssertEqual(store.refreshToken, "refresh")
        XCTAssertTrue(store.isLoggedIn)
    }

    func testClearSessionDropsMemoryFallbackEvenWhenKeychainFails() {
        let tokens = TestSupport.UnreliableTokenStore()
        let store = TokenStore(defaults: isolatedDefaults(), tokens: tokens)
        store.refreshToken = "refresh"
        store.token = "access"
        tokens.failReads = true
        tokens.failClear = true

        store.clearSession()

        XCTAssertNil(store.token)
        XCTAssertNil(store.refreshToken)
        XCTAssertFalse(store.isLoggedIn)

        // Новый вход снова наполняет кэш.
        store.token = "access-2"
        store.refreshToken = "refresh-2"
        XCTAssertEqual(store.token, "access-2")
        XCTAssertEqual(store.refreshToken, "refresh-2")
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

    func testKeychainStoreRoundTripAndClear() throws {
        let store = KeychainTokenStore(service: "muzea-tests-\(UUID().uuidString)")
        store.accessToken = "a"
        store.refreshToken = "r"

        // В CI приложение собирается без подписи, и simulator Keychain может
        // вернуть errSecMissingEntitlement. На подписанной сборке/устройстве
        // эта проверка выполняется полностью.
        guard store.accessToken == "a" else {
            throw XCTSkip("Keychain недоступен в неподписанном симуляторе")
        }

        XCTAssertEqual(store.accessToken, "a")
        XCTAssertEqual(store.refreshToken, "r")

        store.clear()
        XCTAssertNil(store.accessToken)
        XCTAssertNil(store.refreshToken)
    }
}
