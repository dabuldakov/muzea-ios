import XCTest
@testable import Muzea

/// Правовые ссылки и текст удаления должны следовать языку приложения.
final class LegalLinksTests: XCTestCase {

    override func tearDown() {
        LocalizationStore.shared.set(.system)
        super.tearDown()
    }

    func testEnglishUsesEnglishLegalPages() {
        LocalizationStore.shared.set(.en)

        XCTAssertEqual(Legal.policyURL, "https://muzea.su/en/privacy?lang=en")
        XCTAssertEqual(Legal.termsURL, "https://muzea.su/en/terms?lang=en")
        XCTAssertTrue(L10n.deactivateDescription.contains("30 days"))
    }

    func testRussianUsesRussianLegalPages() {
        LocalizationStore.shared.set(.ru)

        XCTAssertEqual(Legal.policyURL, "https://muzea.su/privacy?lang=ru")
        XCTAssertEqual(Legal.termsURL, "https://muzea.su/terms?lang=ru")
        XCTAssertTrue(L10n.deactivateDescription.contains("30"))
    }
}
