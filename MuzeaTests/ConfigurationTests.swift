import XCTest
@testable import Muzea

/// Паритет с Android: бэкенды только по HTTPS, cleartext запрещён.
final class ConfigurationTests: XCTestCase {

    func testBackendsUseHTTPS() {
        XCTAssertEqual(Config.makeupBaseURL.scheme, "https")
        XCTAssertEqual(Config.chatBaseURL.scheme, "https")
        XCTAssertEqual(Config.makeupBaseURL.host, "api-muzea.su")
        XCTAssertEqual(Config.chatBaseURL.host, "chat-muzea.su")
    }

    func testLegalDocumentsUseHTTPS() {
        XCTAssertTrue(Legal.policyURL.hasPrefix("https://"))
        XCTAssertTrue(Legal.termsURL.hasPrefix("https://"))
    }

    func testLegalOperatorContactsMatchAndroid() {
        XCTAssertEqual(Legal.operatorEmail, "dabuldakov@mail.ru")
        XCTAssertEqual(Legal.operatorPhone, "+7 913 800-24-16")
        XCTAssertTrue(Legal.operatorEmailURL.hasPrefix("mailto:"))
        XCTAssertTrue(Legal.operatorPhoneURL.hasPrefix("tel:"))
    }

    func testRelativeImageURLResolvesAgainstHTTPSBackend() {
        let url = ImageURL.makeup("/api/news/image/x.jpeg")
        XCTAssertEqual(url?.absoluteString, "https://api-muzea.su/api/news/image/x.jpeg")
    }
}
