import XCTest
@testable import FitnessTracker

final class WattsAxisTests: XCTestCase {
    func testEmptyOrInvalidReturnsNil() {
        XCTAssertNil(WattsAxis.domain(for: []))
        XCTAssertNil(WattsAxis.domain(for: [0, -10, .nan, .infinity]))
    }

    func testFitsDataWithPaddingAndRounding() {
        // span 30 -> pad max(3, 5) = 5 -> 115...155
        XCTAssertEqual(WattsAxis.domain(for: [120, 135, 150]), 115...155)
    }

    func testLargeSpanUsesTenPercentPadding() {
        // span 200 -> pad 20 -> 80...320
        XCTAssertEqual(WattsAxis.domain(for: [100, 300]), 80...320)
    }

    func testSingleAndConstantValuesGetVisibleRange() {
        XCTAssertEqual(WattsAxis.domain(for: [142]), 135...150)
        XCTAssertEqual(WattsAxis.domain(for: [142, 142, 142]), 135...150)
    }

    func testIgnoresZeroAndInvalidAlongsideValidValues() {
        XCTAssertEqual(WattsAxis.domain(for: [0, 120, .nan, 150]), 115...155)
    }

    func testNeverBelowZero() {
        XCTAssertEqual(WattsAxis.domain(for: [3]), 0...10)
    }

    func testRangeContainsAllValidValues() {
        let values: [Double] = [97.3, 101.8, 133.2, 88.9]
        let domain = WattsAxis.domain(for: values)!
        XCTAssertTrue(values.allSatisfy { domain.contains($0) })
        XCTAssertLessThan(domain.lowerBound, 88.9)
    }

    // MARK: Date (X) domain

    private var newYorkCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return Calendar.mondayFirst(calendar)
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        newYorkCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testDateDomainEmptyIsNil() {
        XCTAssertNil(WattsAxis.dateDomain(periodStarts: [], period: .week, calendar: newYorkCalendar))
    }

    func testWeeklyDomainIsExactlyFirstToLastPointWithNoPadding() {
        let starts = [day(2026, 10, 12), day(2026, 10, 19), day(2026, 10, 26)] // Mondays
        XCTAssertEqual(WattsAxis.dateDomain(periodStarts: starts, period: .week, calendar: newYorkCalendar),
                       day(2026, 10, 12)...day(2026, 10, 26))
    }

    func testMonthlyDomainIsExactlyFirstToLastAndHandlesUnsortedInput() {
        let starts = [day(2026, 10, 1), day(2026, 9, 1)]
        XCTAssertEqual(WattsAxis.dateDomain(periodStarts: starts, period: .month, calendar: newYorkCalendar),
                       day(2026, 9, 1)...day(2026, 10, 1))
    }

    func testDomainAcrossYearBoundaryAndDST() {
        XCTAssertEqual(WattsAxis.dateDomain(periodStarts: [day(2026, 10, 26), day(2027, 1, 4)], period: .week, calendar: newYorkCalendar),
                       day(2026, 10, 26)...day(2027, 1, 4))
    }

    func testSinglePointIsCenteredInOnePeriod() {
        let weekDomain = WattsAxis.dateDomain(periodStarts: [day(2026, 10, 26)], period: .week, calendar: newYorkCalendar)!
        // DST week: 169 hours, centered on the point.
        XCTAssertEqual(day(2026, 10, 26).timeIntervalSince(weekDomain.lowerBound), 169 * 1800)
        XCTAssertEqual(weekDomain.upperBound.timeIntervalSince(day(2026, 10, 26)), 169 * 1800)
        let monthDomain = WattsAxis.dateDomain(periodStarts: [day(2026, 12, 1)], period: .month, calendar: newYorkCalendar)!
        XCTAssertEqual(monthDomain.upperBound.timeIntervalSince(monthDomain.lowerBound), 31 * 86_400)
    }

    // MARK: Segments

    private func point(_ year: Int, _ month: Int, _ day: Int, _ watts: Double) -> WattsAxis.Point {
        .init(start: self.day(year, month, day), watts: watts)
    }

    func testSegmentsEmptyAndSingle() {
        XCTAssertEqual(WattsAxis.segments([], period: .week, calendar: newYorkCalendar), [])
        let one = point(2026, 10, 12, 120)
        XCTAssertEqual(WattsAxis.segments([one], period: .week, calendar: newYorkCalendar), [.init(isGap: false, points: [one])])
    }

    func testConsecutiveWeeksAreOneSolidRun() {
        let points = [point(2026, 10, 12, 120), point(2026, 10, 19, 125), point(2026, 10, 26, 130)]
        XCTAssertEqual(WattsAxis.segments(points, period: .week, calendar: newYorkCalendar), [.init(isGap: false, points: points)])
    }

    func testInteriorMissingWeekBecomesDashedBridgeBetweenMeasuredPoints() {
        let first = point(2026, 10, 5, 110)
        let second = point(2026, 10, 12, 120)
        let third = point(2026, 10, 26, 130) // Oct 19 missing
        XCTAssertEqual(WattsAxis.segments([third, first, second], period: .week, calendar: newYorkCalendar), [
            .init(isGap: false, points: [first, second]),
            .init(isGap: true, points: [second, third]),
            .init(isGap: false, points: [third]),
        ])
    }

    func testWeekSpanningDSTIsStillConsecutive() {
        let beforeDST = point(2026, 10, 26, 120)
        let afterDST = point(2026, 11, 2, 125) // 169-hour week between them
        XCTAssertEqual(WattsAxis.segments([beforeDST, afterDST], period: .week, calendar: newYorkCalendar), [.init(isGap: false, points: [beforeDST, afterDST])])
    }

    func testMonthlyGapsAndYearBoundary() {
        let november = point(2026, 11, 1, 100)
        let december = point(2026, 12, 1, 105)
        let march = point(2027, 3, 1, 110)
        XCTAssertEqual(WattsAxis.segments([november, december, march], period: .month, calendar: newYorkCalendar), [
            .init(isGap: false, points: [november, december]),
            .init(isGap: true, points: [december, march]),
            .init(isGap: false, points: [march]),
        ])
    }
}
