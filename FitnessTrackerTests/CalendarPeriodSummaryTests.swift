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

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        TestSupport.date(year: year, month: month, day: day, hour: hour, minute: minute, calendar: cal)
    }

    func ride(_ date: Date, _ miles: Double, minutes: Double = 30, watts: Int = 85, rpm: Int = 75) -> Workout {
        TestSupport.ride(
            date: date,
            durationMinutes: minutes,
            distanceMiles: miles,
            avgRPM: rpm,
            avgWatts: watts
        )
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

    // MARK: Previous / Next navigation

    func sel(_ p: GroupingPeriod, _ d: Date) -> PastPeriodSelection {
        PastPeriodSelection(period: p, start: p.start(of: d, calendar: cal))
    }

    func testWeekNavigationAcrossDSTAndYearEnd() {
        let w = sel(.week, date(2026, 10, 28))                 // Oct 26 – Nov 1 (DST ends Nov 1)
        XCTAssertEqual(w.moved(by: 1, calendar: cal).start, date(2026, 11, 2, 0))
        XCTAssertEqual(w.moved(by: -1, calendar: cal).start, date(2026, 10, 19, 0))
        let dec = sel(.week, date(2026, 12, 23))               // Dec 21
        XCTAssertEqual(dec.moved(by: 1, calendar: cal).start, date(2026, 12, 28, 0))
        XCTAssertEqual(dec.moved(by: 2, calendar: cal).start, date(2027, 1, 4, 0))
        XCTAssertEqual(cal.component(.weekday, from: dec.moved(by: 2, calendar: cal).start), 2) // Monday
    }

    func testMonthNavigationRolloverAndLeapFebruary() {
        let jan = sel(.month, date(2028, 1, 31))
        let feb = jan.moved(by: 1, calendar: cal)
        XCTAssertEqual(feb.start, date(2028, 2, 1, 0))
        XCTAssertEqual(PeriodSummary.computeCalendar([], period: .month, containing: feb.start, calendar: cal).buckets.count, 29)
        XCTAssertEqual(feb.moved(by: 1, calendar: cal).start, date(2028, 3, 1, 0))
        XCTAssertEqual(sel(.month, date(2026, 12, 5)).moved(by: 1, calendar: cal).start, date(2027, 1, 1, 0))
        XCTAssertEqual(jan.moved(by: -1, calendar: cal).start, date(2027, 12, 1, 0))
    }

    func testYearNavigation() {
        let y = sel(.year, date(2028, 2, 29))
        XCTAssertEqual(y.moved(by: -1, calendar: cal).start, date(2027, 1, 1, 0))
        XCTAssertEqual(y.moved(by: 1, calendar: cal).start, date(2029, 1, 1, 0))
    }

    func testNextStopsAtCurrentPeriod() {
        let now = date(2026, 11, 4)                            // Wed; current week starts Mon Nov 2
        XCTAssertTrue(sel(.week, date(2026, 10, 28)).hasNext(now: now, calendar: cal))
        XCTAssertFalse(sel(.week, now).hasNext(now: now, calendar: cal))
        XCTAssertTrue(sel(.month, date(2026, 10, 1)).hasNext(now: now, calendar: cal))
        XCTAssertFalse(sel(.month, now).hasNext(now: now, calendar: cal))
        XCTAssertFalse(sel(.year, now).hasNext(now: now, calendar: cal))
        XCTAssertTrue(sel(.year, date(2025, 6, 1)).hasNext(now: now, calendar: cal))
    }

    func testNavigatingToEmptyPeriodGivesZeroSummary() {
        let rides = [ride(date(2026, 11, 4), 10)]
        let prev = sel(.week, date(2026, 11, 4)).moved(by: -1, calendar: cal)
        let s = PeriodSummary.computeCalendar(rides, period: .week, containing: prev.start, calendar: cal)
        XCTAssertEqual(s.current.count, 0)
        XCTAssertEqual(s.current.miles, 0)
        XCTAssertEqual(s.buckets.count, 7)
        XCTAssertEqual(s.title, "Week of Oct 26, 2026")
        XCTAssertEqual(s.dateRangeText, "Oct 26 – Nov 1, 2026")
    }

    // MARK: Workout list

    func testPeriodWorkoutsBoundariesAndNewestFirst() {
        let a = ride(date(2026, 11, 1, 23, 59), 1)   // Sun, prior week
        let b = ride(date(2026, 11, 2, 0, 0), 2)     // Mon midnight
        let c = ride(date(2026, 11, 5, 7), 3)
        let d = ride(date(2026, 11, 8, 23, 59), 4)   // Sun, last minute
        let e = ride(date(2026, 11, 9, 0, 0), 5)     // next Monday
        let list = PeriodSummary.calendarWorkouts([c, e, a, d, b], period: .week, containing: date(2026, 11, 4), calendar: cal)
        XCTAssertEqual(list.map(\.distanceMiles), [4, 3, 2])
        let s = summary([c, e, a, d, b], .week, date(2026, 11, 4))
        XCTAssertEqual(s.current.count, list.count)
        XCTAssertEqual(s.current.miles, list.reduce(0) { $0 + $1.distanceMiles }, accuracy: 0.001)
    }

    func testPeriodWorkoutsFollowNavigation() {
        let rides = [ride(date(2026, 10, 30), 1), ride(date(2026, 11, 3), 2), ride(date(2026, 12, 2), 3)]
        var sel = self.sel(.month, date(2026, 11, 15))
        XCTAssertEqual(PeriodSummary.calendarWorkouts(rides, period: .month, containing: sel.start, calendar: cal).map(\.distanceMiles), [2])
        sel = sel.moved(by: -1, calendar: cal)
        XCTAssertEqual(PeriodSummary.calendarWorkouts(rides, period: .month, containing: sel.start, calendar: cal).map(\.distanceMiles), [1])
        sel = sel.moved(by: 2, calendar: cal)
        XCTAssertEqual(PeriodSummary.calendarWorkouts(rides, period: .month, containing: sel.start, calendar: cal).map(\.distanceMiles), [3])
        sel = sel.moved(by: 1, calendar: cal)                   // January 2027: empty
        XCTAssertTrue(PeriodSummary.calendarWorkouts(rides, period: .month, containing: sel.start, calendar: cal).isEmpty)
        XCTAssertEqual(summary(rides, .month, sel.start).current.count, 0)
    }

    func testPeriodWorkoutsAcrossDSTWeek() {
        let late = ride(date(2026, 11, 1, 23, 30), 6)           // after fall-back, still Sun Nov 1
        let list = PeriodSummary.calendarWorkouts([late], period: .week, containing: date(2026, 10, 27), calendar: cal)
        XCTAssertEqual(list.count, 1)
    }

    // MARK: Previous bound (earliest workout) and clamping

    func testPreviousStopsAtEarliestWorkoutsWeek() {
        let earliest = date(2026, 9, 16, 7)                          // Wed; its week starts Mon Sep 14
        let first = sel(.week, earliest)
        XCTAssertEqual(first.start, date(2026, 9, 14, 0))
        XCTAssertFalse(first.hasPrevious(earliest: earliest, calendar: cal))
        XCTAssertTrue(first.moved(by: 1, calendar: cal).hasPrevious(earliest: earliest, calendar: cal))
        // Empty weeks between the earliest ride and now remain reachable.
        XCTAssertTrue(sel(.week, date(2026, 10, 5)).hasPrevious(earliest: earliest, calendar: cal))
    }

    func testPreviousStopsAtEarliestMonthAndYear() {
        let earliest = date(2025, 3, 31, 23, 30)
        XCTAssertFalse(sel(.month, date(2025, 3, 1)).hasPrevious(earliest: earliest, calendar: cal))
        XCTAssertTrue(sel(.month, date(2025, 4, 1)).hasPrevious(earliest: earliest, calendar: cal))
        XCTAssertFalse(sel(.year, date(2025, 7, 1)).hasPrevious(earliest: earliest, calendar: cal))
        XCTAssertTrue(sel(.year, date(2026, 1, 1)).hasPrevious(earliest: earliest, calendar: cal))
    }

    func testNoWorkoutsDisablesPrevious() {
        XCTAssertFalse(sel(.week, date(2026, 11, 4)).hasPrevious(earliest: nil, calendar: cal))
    }

    func testClampKeepsSelectionWithinEarliestAndCurrent() {
        let now = date(2026, 11, 4)
        let earliest = date(2026, 6, 10)
        // Before the earliest ride's month → clamped up to June.
        XCTAssertEqual(sel(.month, date(2026, 2, 3)).clamped(earliest: earliest, now: now, calendar: cal).start, date(2026, 6, 1, 0))
        // Future → clamped down to the current month.
        XCTAssertEqual(sel(.month, date(2027, 1, 3)).clamped(earliest: earliest, now: now, calendar: cal).start, date(2026, 11, 1, 0))
        // Inside → unchanged.
        let inside = sel(.month, date(2026, 8, 20))
        XCTAssertEqual(inside.clamped(earliest: earliest, now: now, calendar: cal), inside)
        // No workouts → only the future bound applies.
        XCTAssertEqual(inside.clamped(earliest: nil, now: now, calendar: cal), inside)
    }

    func testFilteredDatasetDrivesEarliest() {
        // Filtering out the oldest ride moves the Previous bound to the oldest remaining ride.
        let all = [ride(date(2026, 1, 5), 1, watts: 50), ride(date(2026, 8, 5), 2, watts: 120)]
        let filtered = all.filter { $0.avgWatts >= 100 }
        let earliest = filtered.map(\.date).min()
        XCTAssertFalse(sel(.month, date(2026, 8, 1)).hasPrevious(earliest: earliest, calendar: cal))
        XCTAssertTrue(sel(.month, date(2026, 8, 1)).hasPrevious(earliest: all.map(\.date).min(), calendar: cal))
    }

    func testCurrentPeriodHasNoNextAndEarliestEqualsCurrent() {
        let now = date(2026, 11, 4)
        let only = sel(.week, now)
        XCTAssertFalse(only.hasNext(now: now, calendar: cal))
        XCTAssertFalse(only.hasPrevious(earliest: now, calendar: cal))
    }
}
