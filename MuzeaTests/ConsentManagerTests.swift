import XCTest
@testable import Muzea

final class ConsentManagerTests: XCTestCase {

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

    func testNotAcceptedByDefault() {
        XCTAssertFalse(ConsentManager(defaults: defaults).isAccepted)
        XCTAssertNil(ConsentManager(defaults: defaults).acceptedAt)
    }

    func testAcceptPersistsConsent() {
        let consent = ConsentManager(defaults: defaults)
        consent.accept()

        XCTAssertTrue(consent.isAccepted)
        XCTAssertNotNil(consent.acceptedAt)
        XCTAssertTrue(ConsentManager(defaults: defaults).isAccepted)
    }

    func testRevokeClearsConsent() {
        let consent = ConsentManager(defaults: defaults)
        consent.accept()
        consent.revoke()

        XCTAssertFalse(consent.isAccepted)
        XCTAssertNil(consent.acceptedAt)
    }

    func testNewPolicyVersionRequiresConsentAgain() {
        ConsentManager(defaults: defaults, version: 1).accept()

        XCTAssertTrue(ConsentManager(defaults: defaults, version: 1).isAccepted)
        XCTAssertFalse(ConsentManager(defaults: defaults, version: 2).isAccepted)
    }
}
