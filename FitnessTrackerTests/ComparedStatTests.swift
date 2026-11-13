import XCTest
@testable import FitnessTracker

final class ComparedStatTests: XCTestCase {
    private let usLocale = Locale(identifier: "en_US")
    private let german = Locale(identifier: "de_DE")

    private func stat(_ earlierValue: Double, _ laterValue: Double, fractionLength: Int = 0) -> ComparedStat {
        ComparedStat(
            label: "Stat",
            earlierValue: earlierValue,
            laterValue: laterValue,
            fractionLength: fractionLength,
            preference: .neutral,
            formatValue: { value, locale in value.formattedWholeNumber(locale: locale) }
        )
    }

    func testTrendFollowsTheChange() {
        XCTAssertEqual(stat(82, 90).trend, .up)
        XCTAssertEqual(stat(79, 78).trend, .down)
        XCTAssertEqual(stat(31, 31).trend, .unchanged)
    }

    func testChangeTooSmallToShowIsUnchanged() {
        XCTAssertEqual(stat(7.82, 7.824, fractionLength: 2).trend, .unchanged)
        XCTAssertEqual(stat(7.82, 7.83, fractionLength: 2).trend, .up)
        XCTAssertEqual(stat(6.0, 6.04, fractionLength: 1).trend, .unchanged)
    }

    func testChangeTextIsUnsignedAndUsesTheLocale() {
        XCTAssertEqual(stat(7.82, 7.91, fractionLength: 2).changeText(locale: usLocale), "0.09")
        XCTAssertEqual(stat(7.82, 7.91, fractionLength: 2).changeText(locale: german), "0,09")
        XCTAssertEqual(stat(79, 78).changeText(locale: usLocale), "1")
        XCTAssertEqual(stat(100, 1_300).changeText(locale: usLocale), "1,200")
        XCTAssertEqual(stat(31, 31).changeText(locale: usLocale), "0")
    }

    func testSectionsCoverEveryStatInOrder() {
        let calendar = Calendar.app
        let earlier = TestSupport.ride(date: TestSupport.date(year: 2026, month: 10, day: 27, calendar: calendar))
        let later = TestSupport.ride(date: TestSupport.date(year: 2026, month: 11, day: 4, calendar: calendar))
        let sections = ComparedSection.all(earlier: earlier, later: later)
        XCTAssertEqual(sections.map(\.title), ["Effort", "Power", "Resistance", "Incline"])
        XCTAssertEqual(sections.flatMap { $0.stats.map(\.label) }, [
            "Distance", "Duration", "Calories", "Elevation",
            "Avg watts", "Avg RPM",
            "Average", "Max",
            "Average", "Max",
        ])
    }

    func testOnlyClearImprovementsAreColored() {
        let calendar = Calendar.app
        let ride = TestSupport.ride(date: TestSupport.date(year: 2026, month: 11, day: 4, calendar: calendar))
        let higherIsBetter = ComparedSection.all(earlier: ride, later: ride)
            .flatMap(\.stats)
            .filter { $0.preference == .higherIsBetter }
            .map(\.label)
        XCTAssertEqual(higherIsBetter, ["Distance", "Calories", "Avg watts"])
    }
}
