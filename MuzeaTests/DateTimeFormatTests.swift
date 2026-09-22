import XCTest
@testable import Muzea

final class DateTimeFormatTests: XCTestCase {

    private let moscow = TimeZone(identifier: "Europe/Moscow")!
    private let utc = TimeZone(identifier: "UTC")!

    func testFullConvertsUtcToLocal() {
        XCTAssertEqual(
            DateTimeFormat.full("2026-09-22T12:00:00", timeZone: moscow),
            "2026-09-22 15:00"
        )
    }

    func testDateInLocalZone() {
        XCTAssertEqual(
            DateTimeFormat.date("2026-09-22T12:00:00", timeZone: moscow),
            "2026-09-22"
        )
    }

    func testNanosecondPrecisionIsHandled() {
        XCTAssertEqual(
            DateTimeFormat.full("2026-09-22T12:00:00.123456789", timeZone: utc),
            "2026-09-22 12:00"
        )
    }

    func testZSuffixIsHandled() {
        XCTAssertEqual(
            DateTimeFormat.full("2026-09-22T12:00:00Z", timeZone: utc),
            "2026-09-22 12:00"
        )
    }

    func testCrossMidnightShiftsDate() {
        XCTAssertEqual(
            DateTimeFormat.full("2026-09-21T22:00:00Z", timeZone: moscow),
            "2026-09-22 01:00"
        )
        XCTAssertEqual(
            DateTimeFormat.date("2026-09-21T22:00:00Z", timeZone: moscow),
            "2026-09-22"
        )
    }

    func testEmptyAndNilReturnEmptyString() {
        XCTAssertEqual(DateTimeFormat.full(nil), "")
        XCTAssertEqual(DateTimeFormat.full(""), "")
        XCTAssertEqual(DateTimeFormat.date(nil), "")
        XCTAssertEqual(DateTimeFormat.date(""), "")
    }

    func testMalformedInputIsReturnedAsIs() {
        XCTAssertEqual(DateTimeFormat.full("not-a-date"), "not-a-date")
    }
}