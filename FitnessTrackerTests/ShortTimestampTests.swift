import XCTest
@testable import FitnessTracker

final class ShortTimestampTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_US")
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testOmitsYearForCurrentYear() {
        let text = date(2026, 11, 11, 15, 35).shortTimestamp(relativeTo: date(2026, 12, 1, 9, 0), calendar: calendar)
        XCTAssertFalse(text.contains("2026"), text)
        XCTAssertTrue(text.contains("Nov 11"), text)
        XCTAssertTrue(text.contains("3:35"), text)
    }

    func testIncludesYearForPastYear() {
        let text = date(2025, 11, 11, 15, 35).shortTimestamp(relativeTo: date(2026, 1, 2, 9, 0), calendar: calendar)
        XCTAssertTrue(text.contains("2025"), text)
        XCTAssertTrue(text.contains("Nov 11"), text)
    }
}
