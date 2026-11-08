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
        let d = WattsAxis.domain(for: values)!
        XCTAssertTrue(values.allSatisfy { d.contains($0) })
        XCTAssertLessThan(d.lowerBound, 88.9)
    }

    // MARK: Date (X) domain

    private var nyCal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return Calendar.mondayFirst(c)
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        nyCal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testDateDomainEmptyIsNil() {
        XCTAssertNil(WattsAxis.dateDomain(periodStarts: [], period: .week, calendar: nyCal))
    }

    func testWeeklyDomainCoversFirstThroughEndOfLastWeek() {
        let starts = [day(2026, 10, 12), day(2026, 10, 19), day(2026, 10, 26)] // Mondays
        XCTAssertEqual(WattsAxis.dateDomain(periodStarts: starts, period: .week, calendar: nyCal),
                       day(2026, 10, 12)...day(2026, 11, 2))
    }

    func testWeeklyDomainAcrossDSTEndsAtLocalMidnight() {
        // Week of Oct 26 2026 contains the Nov 1 fall-back (a 169-hour week).
        let d = WattsAxis.dateDomain(periodStarts: [day(2026, 10, 26)], period: .week, calendar: nyCal)!
        XCTAssertEqual(d.upperBound, day(2026, 11, 2))
        XCTAssertEqual(d.upperBound.timeIntervalSince(d.lowerBound), 169 * 3600)
    }

    func testMonthlyDomainUsesRealMonthLengthsAndUnsortedInput() {
        let starts = [day(2026, 3, 1), day(2026, 1, 1), day(2026, 2, 1)]
        XCTAssertEqual(WattsAxis.dateDomain(periodStarts: starts, period: .month, calendar: nyCal),
                       day(2026, 1, 1)...day(2026, 4, 1))
    }

    func testSinglePeriodAndYearBoundary() {
        XCTAssertEqual(WattsAxis.dateDomain(periodStarts: [day(2026, 12, 1)], period: .month, calendar: nyCal),
                       day(2026, 12, 1)...day(2027, 1, 1))
        XCTAssertEqual(WattsAxis.dateDomain(periodStarts: [day(2026, 12, 28)], period: .week, calendar: nyCal),
                       day(2026, 12, 28)...day(2027, 1, 4))
    }

    // MARK: Segments

    private func pt(_ y: Int, _ m: Int, _ d: Int, _ w: Double) -> WattsAxis.Point { .init(start: day(y, m, d), watts: w) }

    func testSegmentsEmptyAndSingle() {
        XCTAssertEqual(WattsAxis.segments([], period: .week, calendar: nyCal), [])
        let one = pt(2026, 10, 12, 120)
        XCTAssertEqual(WattsAxis.segments([one], period: .week, calendar: nyCal), [.init(isGap: false, points: [one])])
    }

    func testConsecutiveWeeksAreOneSolidRun() {
        let p = [pt(2026, 10, 12, 120), pt(2026, 10, 19, 125), pt(2026, 10, 26, 130)]
        XCTAssertEqual(WattsAxis.segments(p, period: .week, calendar: nyCal), [.init(isGap: false, points: p)])
    }

    func testInteriorMissingWeekBecomesDashedBridgeBetweenMeasuredPoints() {
        let a = pt(2026, 10, 5, 110), b = pt(2026, 10, 12, 120), c = pt(2026, 10, 26, 130) // Oct 19 missing
        XCTAssertEqual(WattsAxis.segments([c, a, b], period: .week, calendar: nyCal), [
            .init(isGap: false, points: [a, b]),
            .init(isGap: true, points: [b, c]),
            .init(isGap: false, points: [c]),
        ])
    }

    func testWeekSpanningDSTIsStillConsecutive() {
        let a = pt(2026, 10, 26, 120), b = pt(2026, 11, 2, 125) // 169-hour week between them
        XCTAssertEqual(WattsAxis.segments([a, b], period: .week, calendar: nyCal), [.init(isGap: false, points: [a, b])])
    }

    func testMonthlyGapsAndYearBoundary() {
        let a = pt(2026, 11, 1, 100), b = pt(2026, 12, 1, 105), c = pt(2027, 3, 1, 110)
        XCTAssertEqual(WattsAxis.segments([a, b, c], period: .month, calendar: nyCal), [
            .init(isGap: false, points: [a, b]),
            .init(isGap: true, points: [b, c]),
            .init(isGap: false, points: [c]),
        ])
    }
}
