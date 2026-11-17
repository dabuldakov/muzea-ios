import XCTest
@testable import Muzea

final class AuthNoticeStoreTests: XCTestCase {

    func testNoticeIsShownOnlyOnce() {
        let suite = "auth-notice-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = AuthNoticeStore(defaults: defaults)
        XCTAssertTrue(store.shouldShowPasswordlessNotice)

        store.markPasswordlessNoticeShown()
        XCTAssertFalse(store.shouldShowPasswordlessNotice)
    }

    func testFreshStoreShowsNotice() {
        let suite = "auth-notice-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(false, forKey: "auth.passwordlessNoticeShown")
        XCTAssertTrue(AuthNoticeStore(defaults: defaults).shouldShowPasswordlessNotice)
    }
}

@MainActor
final class AuthEmailValidationTests: XCTestCase {

    func testNormalizeTrimsAndLowercases() {
        XCTAssertEqual(
            AuthViewModel.normalizeEmail("  User@Mail.RU\u{00A0}"),
            "user@mail.ru"
        )
    }

    func testNormalizeRemovesZeroWidthCharacters() {
        XCTAssertEqual(
            AuthViewModel.normalizeEmail("user@mail.ru\u{200B}"),
            "user@mail.ru"
        )
        XCTAssertEqual(
            AuthViewModel.normalizeEmail("\u{FEFF}User@Mail.ru"),
            "user@mail.ru"
        )
    }

    func testAcceptsAndroidLikeEmails() {
        XCTAssertTrue(AuthViewModel.isValidEmail("a@b.co"))
        XCTAssertTrue(AuthViewModel.isValidEmail("a.b+c@sub.example.co"))
        XCTAssertTrue(AuthViewModel.isValidEmail("user_name-1@mail.ru"))
    }

    func testRejectsInternalSpaces() {
        XCTAssertFalse(AuthViewModel.isValidEmail("da buldakov@mail.ru"))
        XCTAssertFalse(AuthViewModel.isValidEmail("user@ mail.ru"))
    }

    func testRejectsNonAscii() {
        XCTAssertFalse(AuthViewModel.isValidEmail("пользователь@mail.ru"))
        XCTAssertFalse(AuthViewModel.isValidEmail("user@почта.рф"))
    }

    func testRejectsBrokenDomains() {
        XCTAssertFalse(AuthViewModel.isValidEmail("user@mail"))
        XCTAssertFalse(AuthViewModel.isValidEmail("user@.ru"))
        XCTAssertFalse(AuthViewModel.isValidEmail("user@mail."))
        XCTAssertFalse(AuthViewModel.isValidEmail("user@@mail.ru"))
        XCTAssertFalse(AuthViewModel.isValidEmail("@mail.ru"))
    }

    func testRequestLoginCodeRejectsEmailWithSpaceWithoutRepositoryCall() async {
        let repository = FakeAuthRepository()
        let viewModel = AuthViewModel(repository: repository)

        let ok = await viewModel.requestLoginCode(email: "da buldakov@mail.ru")

        XCTAssertFalse(ok)
        XCTAssertTrue(repository.requestedCodes.isEmpty)
        XCTAssertNotNil(viewModel.state.error)
    }

    func testRequestLoginCodeSendsNormalizedEmail() async {
        let repository = FakeAuthRepository()
        let viewModel = AuthViewModel(repository: repository)

        let ok = await viewModel.requestLoginCode(email: " User.Name+tag@Mail.RU\u{200B} ")

        XCTAssertTrue(ok)
        XCTAssertEqual(repository.requestedCodes, ["user.name+tag@mail.ru"])
    }
}
