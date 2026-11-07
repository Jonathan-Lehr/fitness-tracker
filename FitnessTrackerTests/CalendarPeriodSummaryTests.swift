import XCTest
@testable import FitnessTracker

/// Calendar-period (past week / month / year) summaries: Monday-first weeks, local-time
/// boundaries across DST, month lengths and leap years, ride filtering and comparisons.
final class CalendarPeriodSummaryTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        c.locale = Locale(identifier: "en_US")
        return Calendar.mondayFirst(c)
    }()

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func ride(_ d: Date, _ miles: Double, minutes: Double = 30, watts: Int = 85, rpm: Int = 75) -> Workout {
        Workout(date: d, program: nil, durationMinutes: minutes, distanceMiles: miles, calories: 300,
                elevationFeet: 500, avgRPM: rpm, avgWatts: watts, inclineAvg: 0, inclineMax: 0,
                resistanceAvg: 10, resistanceMax: 15)
    }

    func summary(_ rides: [Workout], _ p: GroupingPeriod, _ d: Date) -> PeriodSummary {
        PeriodSummary.computeCalendar(rides, period: p, containing: d, calendar: cal)
    }

    // MARK: Week

    func testWeekIsMondayToSundayWithPriorWeek() {
        let rides = [
            ride(date(2026, 11, 1, 23, 59), 4),   // Sun Nov 1 → prior week
            ride(date(2026, 11, 2, 0, 0), 10),    // Mon Nov 2 midnight → this week
            ride(date(2026, 11, 8, 23, 59), 5),   // Sun Nov 8 → this week
            ride(date(2026, 11, 9, 0, 0), 99),    // Mon Nov 9 → next week, excluded
        ]
        let s = summary(rides, .week, date(2026, 11, 4))
        XCTAssertEqual(s.kind, .calendar)
        XCTAssertEqual(s.interval.start, date(2026, 11, 2, 0))
        XCTAssertEqual(s.interval.end, date(2026, 11, 9, 0))
        XCTAssertEqual(s.current.count, 2)
        XCTAssertEqual(s.current.miles, 15, accuracy: 0.001)
        XCTAssertEqual(s.previous.count, 1)
        XCTAssertEqual(s.previous.miles, 4, accuracy: 0.001)
        XCTAssertEqual(s.buckets.count, 7)
        XCTAssertEqual(s.buckets.compactMap(\.label), ["M", "T", "W", "T", "F", "S", "S"])
        XCTAssertEqual(s.buckets[0].miles, 10, accuracy: 0.001)
        XCTAssertEqual(s.buckets[6].miles, 5, accuracy: 0.001)
        XCTAssertEqual(s.title, "Week of Nov 2, 2026")
        XCTAssertEqual(s.dateRangeText, "Nov 2 – Nov 8, 2026")
        XCTAssertEqual(s.deltaText, "+11.0 mi vs prior week")
    }

    func testWeekAcrossDSTEndHasSevenMidnightBuckets() {
        // DST ends Sun Nov 1, 2026 in New York: the week Oct 26 – Nov 1 is 7 days + 1 hour.
        let s = summary([], .week, date(2026, 10, 28))
        XCTAssertEqual(s.interval.start, date(2026, 10, 26, 0))
        XCTAssertEqual(s.interval.end, date(2026, 11, 2, 0))
        XCTAssertEqual(s.interval.duration, 7 * 86_400 + 3_600)
        XCTAssertEqual(s.buckets.count, 7)
        for b in s.buckets { XCTAssertEqual(cal.component(.hour, from: b.start), 0) }
        XCTAssertEqual(s.buckets.last?.start, date(2026, 11, 1, 0))
    }

    func testWeekSpanningNewYear() {
        let s = summary([ride(date(2027, 1, 1), 7)], .week, date(2026, 12, 30))
        XCTAssertEqual(s.interval.start, date(2026, 12, 28, 0))
        XCTAssertEqual(s.title, "Week of Dec 28, 2026")
        XCTAssertEqual(s.dateRangeText, "Dec 28, 2026 – Jan 3, 2027")
        XCTAssertEqual(s.current.miles, 7, accuracy: 0.001)
    }

    // MARK: Month

    func testMonthLengthsAndLeapYear() {
        XCTAssertEqual(summary([], .month, date(2027, 2, 10)).buckets.count, 28)
        XCTAssertEqual(summary([], .month, date(2028, 2, 10)).buckets.count, 29)
        XCTAssertEqual(summary([], .month, date(2026, 4, 10)).buckets.count, 30)
        let mar = summary([], .month, date(2026, 3, 10))
        XCTAssertEqual(mar.buckets.count, 31)
        XCTAssertEqual(mar.buckets.compactMap(\.label), ["1", "8", "15", "22", "29"])
        XCTAssertEqual(mar.dateRangeText, "Mar 1 – Mar 31, 2026")
        XCTAssertEqual(mar.title, "March 2026")
    }

    func testMonthAcrossDSTStartAndPriorMonth() {
        // DST starts Sun Mar 8, 2026 in New York.
        let rides = [
            ride(date(2026, 2, 28, 23), 3),          // February → prior
            ride(date(2026, 3, 8, 3), 6),            // just after the spring-forward gap
            ride(date(2026, 3, 31, 23, 59), 2),
            ride(date(2026, 4, 1, 0), 50),           // April, excluded
        ]
        let s = summary(rides, .month, date(2026, 3, 15))
        XCTAssertEqual(s.interval.start, date(2026, 3, 1, 0))
        XCTAssertEqual(s.interval.end, date(2026, 4, 1, 0))
        for b in s.buckets { XCTAssertEqual(cal.component(.hour, from: b.start), 0) }
        XCTAssertEqual(s.buckets[7].miles, 6, accuracy: 0.001)     // Mar 8
        XCTAssertEqual(s.buckets[30].miles, 2, accuracy: 0.001)    // Mar 31
        XCTAssertEqual(s.current.miles, 8, accuracy: 0.001)
        XCTAssertEqual(s.previous.miles, 3, accuracy: 0.001)
        XCTAssertEqual(s.previous.count, 1)
        XCTAssertEqual(s.deltaText, "+5.0 mi vs prior month")
    }

    // MARK: Year

    func testYearHasTwelveMonthsFromJanuary() {
        let rides = [ride(date(2025, 12, 31, 23), 9), ride(date(2026, 1, 1, 0), 4), ride(date(2026, 12, 31, 22), 1)]
        let s = summary(rides, .year, date(2026, 6, 1))
        XCTAssertEqual(s.interval.start, date(2026, 1, 1, 0))
        XCTAssertEqual(s.interval.end, date(2027, 1, 1, 0))
        XCTAssertEqual(s.buckets.count, 12)
        XCTAssertEqual(s.buckets.first?.start, date(2026, 1, 1, 0))
        XCTAssertEqual(s.buckets.last?.start, date(2026, 12, 1, 0))
        XCTAssertEqual(s.buckets.last?.end, date(2027, 1, 1, 0))
        XCTAssertEqual(s.buckets.compactMap(\.label), ["J", "A", "J", "O"])
        XCTAssertEqual(s.buckets[0].miles, 4, accuracy: 0.001)
        XCTAssertEqual(s.buckets[11].miles, 1, accuracy: 0.001)
        XCTAssertEqual(s.previous.miles, 9, accuracy: 0.001)
        XCTAssertEqual(s.title, "2026")
        XCTAssertEqual(s.dateRangeText, "Jan 1 – Dec 31, 2026")
        XCTAssertEqual(s.deltaText, "−4.0 mi vs prior year")
    }

    func testLeapYearPreviousYearComparison() {
        let s = summary([ride(date(2028, 2, 29), 5)], .year, date(2029, 3, 1))
        XCTAssertEqual(s.previous.miles, 5, accuracy: 0.001)
        XCTAssertEqual(s.previous.count, 1)
    }

    // MARK: Metrics

    func testWattsAndRPMDurationWeightedSkippingZeros() {
        let rides = [
            ride(date(2026, 11, 3), 5, minutes: 30, watts: 100, rpm: 80),
            ride(date(2026, 11, 4), 5, minutes: 60, watts: 70, rpm: 0),     // RPM not recorded
            ride(date(2026, 11, 5), 5, minutes: 20, watts: 0, rpm: 90),     // watts not recorded
        ]
        let s = summary(rides, .week, date(2026, 11, 4))
        XCTAssertEqual(s.current.averageWatts!, (100 * 30 + 70 * 60) / 90.0, accuracy: 0.001)
        XCTAssertEqual(s.current.averageRPM!, (80 * 30 + 90 * 20) / 50.0, accuracy: 0.001)
        XCTAssertNil(s.previous.averageWatts)
        XCTAssertEqual(s.deltaText(.watts), "—")
    }

    func testEmptyPeriod() {
        let s = summary([], .month, date(2026, 5, 5))
        XCTAssertEqual(s.current.count, 0)
        XCTAssertEqual(s.deltaText, "±0.0 mi vs prior month")
        XCTAssertEqual(s.valueText(.watts).value, "—")
    }

    // MARK: Rolling summaries are unchanged

    func testRollingSummaryStillRolling() {
        let now = date(2026, 11, 4)
        let s = PeriodSummary.compute([ride(date(2026, 10, 29), 3)], period: .week, now: now, calendar: cal)
        XCTAssertEqual(s.kind, .rolling)
        XCTAssertEqual(s.interval.start, date(2026, 10, 29, 0))
        XCTAssertEqual(s.title, "Last 7 Days")
        XCTAssertEqual(s.deltaText, "+3.0 mi vs prior 7 days")
    }
}
