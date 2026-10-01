import XCTest
@testable import Muzea

final class LastSeenFormatterTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!
    private let now = Date(timeIntervalSince1970: 1_800_000_000) // 2027-01-15 08:00 UTC

    private func iso(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = utc
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.string(from: date)
    }

    func testMinutesAgoCountsFullMinutes() {
        XCTAssertEqual(LastSeenFormatter.minutesAgo(iso(now), now: now), 0)
        XCTAssertEqual(LastSeenFormatter.minutesAgo(iso(now.addingTimeInterval(-5 * 60)), now: now), 5)
        XCTAssertEqual(LastSeenFormatter.minutesAgo(iso(now.addingTimeInterval(-120 * 60)), now: now), 120)
    }

    func testMinutesAgoReturnsNilWhenNeverOnline() {
        XCTAssertNil(LastSeenFormatter.minutesAgo(nil, now: now))
        XCTAssertNil(LastSeenFormatter.minutesAgo("", now: now))
    }

    func testMinutesAgoClampsFutureTimestampsToZero() {
        XCTAssertEqual(LastSeenFormatter.minutesAgo(iso(now.addingTimeInterval(30 * 60)), now: now), 0)
    }

    func testMinutesAgoReturnsNilForUnparsableString() {
        XCTAssertNil(LastSeenFormatter.minutesAgo("не дата", now: now))
        XCTAssertNil(LastSeenFormatter.parse("не дата"))
    }

    func testParseTreatsZSuffixAndPlainZoneAsSameInstant() {
        let expected = LastSeenFormatter.parse("2026-09-22T12:00:00")
        XCTAssertEqual(expected, LastSeenFormatter.parse("2026-09-22T12:00:00Z"))
    }

    func testParseToleratesFractionalSeconds() {
        XCTAssertNotNil(LastSeenFormatter.parse("2026-09-22T12:00:00.123456Z"))
    }

    func testLabelUsesRelativeUnits() {
        XCTAssertEqual(
            LastSeenFormatter.label(lastSeenAt: iso(now.addingTimeInterval(-30)), now: now, timeZone: utc),
            "был(а) только что"
        )
        XCTAssertEqual(
            LastSeenFormatter.label(lastSeenAt: iso(now.addingTimeInterval(-5 * 60)), now: now, timeZone: utc),
            "был(а) 5 мин назад"
        )
        XCTAssertEqual(
            LastSeenFormatter.label(lastSeenAt: iso(now.addingTimeInterval(-3 * 60 * 60)), now: now, timeZone: utc),
            "был(а) 3 ч назад"
        )
    }

    func testLabelFallsBackToCalendarTimeAfterDay() {
        XCTAssertEqual(
            LastSeenFormatter.label(lastSeenAt: iso(now.addingTimeInterval(-2 * 24 * 60 * 60)), now: now, timeZone: utc),
            "был(а) в сети 2027-01-13 08:00"
        )
    }

    func testLabelWithoutTimestampIsOffline() {
        XCTAssertEqual(LastSeenFormatter.label(lastSeenAt: nil, now: now), "офлайн")
        XCTAssertEqual(LastSeenFormatter.label(lastSeenAt: "", now: now), "офлайн")
        XCTAssertEqual(LastSeenFormatter.label(lastSeenAt: "не дата", now: now), "офлайн")
    }
}
