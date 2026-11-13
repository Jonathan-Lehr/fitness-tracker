import XCTest
@testable import FitnessTracker

/// Calendar-period (past week / month / year) summaries: Monday-first weeks, local-time
/// boundaries across DST, month lengths and leap years, ride filtering and comparisons.
final class CalendarPeriodSummaryTests: XCTestCase {
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US")
        return Calendar.mondayFirst(calendar)
    }()

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        TestSupport.date(year: year, month: month, day: day, hour: hour, minute: minute, calendar: calendar)
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

    func summary(_ rides: [Workout], _ period: GroupingPeriod, _ date: Date) -> PeriodSummary {
        PeriodSummary.computeCalendar(rides, period: period, containing: date, calendar: calendar)
    }

    // MARK: Week

    func testWeekIsMondayToSundayWithPriorWeek() {
        let rides = [
            ride(date(2026, 11, 1, 23, 59), 4),   // Sun Nov 1 → prior week
            ride(date(2026, 11, 2, 0, 0), 10),    // Mon Nov 2 midnight → this week
            ride(date(2026, 11, 8, 23, 59), 5),   // Sun Nov 8 → this week
            ride(date(2026, 11, 9, 0, 0), 99),    // Mon Nov 9 → next week, excluded
        ]
        let summary = summary(rides, .week, date(2026, 11, 4))
        XCTAssertEqual(summary.kind, .calendar)
        XCTAssertEqual(summary.interval.start, date(2026, 11, 2, 0))
        XCTAssertEqual(summary.interval.end, date(2026, 11, 9, 0))
        XCTAssertEqual(summary.current.count, 2)
        XCTAssertEqual(summary.current.miles, 15, accuracy: 0.001)
        XCTAssertEqual(summary.previous.count, 1)
        XCTAssertEqual(summary.previous.miles, 4, accuracy: 0.001)
        XCTAssertEqual(summary.buckets.count, 7)
        XCTAssertEqual(summary.buckets.compactMap(\.label), ["M", "T", "W", "T", "F", "S", "S"])
        XCTAssertEqual(summary.buckets[0].miles, 10, accuracy: 0.001)
        XCTAssertEqual(summary.buckets[6].miles, 5, accuracy: 0.001)
        XCTAssertEqual(summary.title, "Week of Nov 2, 2026")
        XCTAssertEqual(summary.dateRangeText, "Nov 2 – Nov 8, 2026")
        XCTAssertEqual(summary.deltaText, "+11.0 mi vs prior week")
    }

    func testWeekAcrossDSTEndHasSevenMidnightBuckets() {
        // DST ends Sun Nov 1, 2026 in New York: the week Oct 26 – Nov 1 is 7 days + 1 hour.
        let summary = summary([], .week, date(2026, 10, 28))
        XCTAssertEqual(summary.interval.start, date(2026, 10, 26, 0))
        XCTAssertEqual(summary.interval.end, date(2026, 11, 2, 0))
        XCTAssertEqual(summary.interval.duration, 7 * 86_400 + 3_600)
        XCTAssertEqual(summary.buckets.count, 7)
        for bucket in summary.buckets { XCTAssertEqual(calendar.component(.hour, from: bucket.start), 0) }
        XCTAssertEqual(summary.buckets.last?.start, date(2026, 11, 1, 0))
    }

    func testWeekSpanningNewYear() {
        let summary = summary([ride(date(2027, 1, 1), 7)], .week, date(2026, 12, 30))
        XCTAssertEqual(summary.interval.start, date(2026, 12, 28, 0))
        XCTAssertEqual(summary.title, "Week of Dec 28, 2026")
        XCTAssertEqual(summary.dateRangeText, "Dec 28, 2026 – Jan 3, 2027")
        XCTAssertEqual(summary.current.miles, 7, accuracy: 0.001)
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
        let summary = summary(rides, .month, date(2026, 3, 15))
        XCTAssertEqual(summary.interval.start, date(2026, 3, 1, 0))
        XCTAssertEqual(summary.interval.end, date(2026, 4, 1, 0))
        for bucket in summary.buckets { XCTAssertEqual(calendar.component(.hour, from: bucket.start), 0) }
        XCTAssertEqual(summary.buckets[7].miles, 6, accuracy: 0.001)     // Mar 8
        XCTAssertEqual(summary.buckets[30].miles, 2, accuracy: 0.001)    // Mar 31
        XCTAssertEqual(summary.current.miles, 8, accuracy: 0.001)
        XCTAssertEqual(summary.previous.miles, 3, accuracy: 0.001)
        XCTAssertEqual(summary.previous.count, 1)
        XCTAssertEqual(summary.deltaText, "+5.0 mi vs prior month")
    }

    // MARK: Year

    func testYearHasTwelveMonthsFromJanuary() {
        let rides = [ride(date(2025, 12, 31, 23), 9), ride(date(2026, 1, 1, 0), 4), ride(date(2026, 12, 31, 22), 1)]
        let summary = summary(rides, .year, date(2026, 6, 1))
        XCTAssertEqual(summary.interval.start, date(2026, 1, 1, 0))
        XCTAssertEqual(summary.interval.end, date(2027, 1, 1, 0))
        XCTAssertEqual(summary.buckets.count, 12)
        XCTAssertEqual(summary.buckets.first?.start, date(2026, 1, 1, 0))
        XCTAssertEqual(summary.buckets.last?.start, date(2026, 12, 1, 0))
        XCTAssertEqual(summary.buckets.last?.end, date(2027, 1, 1, 0))
        XCTAssertEqual(summary.buckets.compactMap(\.label), ["J", "A", "J", "O"])
        XCTAssertEqual(summary.buckets[0].miles, 4, accuracy: 0.001)
        XCTAssertEqual(summary.buckets[11].miles, 1, accuracy: 0.001)
        XCTAssertEqual(summary.previous.miles, 9, accuracy: 0.001)
        XCTAssertEqual(summary.title, "2026")
        XCTAssertEqual(summary.dateRangeText, "Jan 1 – Dec 31, 2026")
        XCTAssertEqual(summary.deltaText, "−4.0 mi vs prior year")
    }

    func testLeapYearPreviousYearComparison() {
        let summary = summary([ride(date(2028, 2, 29), 5)], .year, date(2029, 3, 1))
        XCTAssertEqual(summary.previous.miles, 5, accuracy: 0.001)
        XCTAssertEqual(summary.previous.count, 1)
    }

    // MARK: Metrics

    func testWattsAndRPMDurationWeightedSkippingZeros() {
        let rides = [
            ride(date(2026, 11, 3), 5, minutes: 30, watts: 100, rpm: 80),
            ride(date(2026, 11, 4), 5, minutes: 60, watts: 70, rpm: 0),     // RPM not recorded
            ride(date(2026, 11, 5), 5, minutes: 20, watts: 0, rpm: 90),     // watts not recorded
        ]
        let summary = summary(rides, .week, date(2026, 11, 4))
        XCTAssertEqual(summary.current.averageWatts!, (100 * 30 + 70 * 60) / 90.0, accuracy: 0.001)
        XCTAssertEqual(summary.current.averageRPM!, (80 * 30 + 90 * 20) / 50.0, accuracy: 0.001)
        XCTAssertNil(summary.previous.averageWatts)
        XCTAssertEqual(summary.deltaText(.watts), "—")
    }

    func testEmptyPeriod() {
        let summary = summary([], .month, date(2026, 5, 5))
        XCTAssertEqual(summary.current.count, 0)
        XCTAssertEqual(summary.deltaText, "±0.0 mi vs prior month")
        XCTAssertEqual(summary.valueText(.watts).value, "—")
    }

    // MARK: Rolling summaries are unchanged

    func testRollingSummaryStillRolling() {
        let now = date(2026, 11, 4)
        let summary = PeriodSummary.compute([ride(date(2026, 10, 29), 3)], period: .week, now: now, calendar: calendar)
        XCTAssertEqual(summary.kind, .rolling)
        XCTAssertEqual(summary.interval.start, date(2026, 10, 29, 0))
        XCTAssertEqual(summary.title, "Last 7 Days")
        XCTAssertEqual(summary.deltaText, "+3.0 mi vs prior 7 days")
    }

    // MARK: Previous / Next navigation

    func selection(_ period: GroupingPeriod, _ date: Date) -> PastPeriodSelection {
        PastPeriodSelection(period: period, start: period.start(of: date, calendar: calendar))
    }

    func testWeekNavigationAcrossDSTAndYearEnd() {
        let weekSelection = selection(.week, date(2026, 10, 28))                 // Oct 26 – Nov 1 (DST ends Nov 1)
        XCTAssertEqual(weekSelection.moved(by: 1, calendar: calendar).start, date(2026, 11, 2, 0))
        XCTAssertEqual(weekSelection.moved(by: -1, calendar: calendar).start, date(2026, 10, 19, 0))
        let decemberWeek = selection(.week, date(2026, 12, 23))               // Dec 21
        XCTAssertEqual(decemberWeek.moved(by: 1, calendar: calendar).start, date(2026, 12, 28, 0))
        XCTAssertEqual(decemberWeek.moved(by: 2, calendar: calendar).start, date(2027, 1, 4, 0))
        XCTAssertEqual(calendar.component(.weekday, from: decemberWeek.moved(by: 2, calendar: calendar).start), 2) // Monday
    }

    func testMonthNavigationRolloverAndLeapFebruary() {
        let jan = selection(.month, date(2028, 1, 31))
        let feb = jan.moved(by: 1, calendar: calendar)
        XCTAssertEqual(feb.start, date(2028, 2, 1, 0))
        XCTAssertEqual(PeriodSummary.computeCalendar([], period: .month, containing: feb.start, calendar: calendar).buckets.count, 29)
        XCTAssertEqual(feb.moved(by: 1, calendar: calendar).start, date(2028, 3, 1, 0))
        XCTAssertEqual(selection(.month, date(2026, 12, 5)).moved(by: 1, calendar: calendar).start, date(2027, 1, 1, 0))
        XCTAssertEqual(jan.moved(by: -1, calendar: calendar).start, date(2027, 12, 1, 0))
    }

    func testYearNavigation() {
        let yearSelection = selection(.year, date(2028, 2, 29))
        XCTAssertEqual(yearSelection.moved(by: -1, calendar: calendar).start, date(2027, 1, 1, 0))
        XCTAssertEqual(yearSelection.moved(by: 1, calendar: calendar).start, date(2029, 1, 1, 0))
    }

    func testNextStopsAtCurrentPeriod() {
        let now = date(2026, 11, 4)                            // Wed; current week starts Mon Nov 2
        XCTAssertTrue(selection(.week, date(2026, 10, 28)).hasNext(now: now, calendar: calendar))
        XCTAssertFalse(selection(.week, now).hasNext(now: now, calendar: calendar))
        XCTAssertTrue(selection(.month, date(2026, 10, 1)).hasNext(now: now, calendar: calendar))
        XCTAssertFalse(selection(.month, now).hasNext(now: now, calendar: calendar))
        XCTAssertFalse(selection(.year, now).hasNext(now: now, calendar: calendar))
        XCTAssertTrue(selection(.year, date(2025, 6, 1)).hasNext(now: now, calendar: calendar))
    }

    func testNavigatingToEmptyPeriodGivesZeroSummary() {
        let rides = [ride(date(2026, 11, 4), 10)]
        let previousSelection = selection(.week, date(2026, 11, 4)).moved(by: -1, calendar: calendar)
        let summary = PeriodSummary.computeCalendar(rides, period: .week, containing: previousSelection.start, calendar: calendar)
        XCTAssertEqual(summary.current.count, 0)
        XCTAssertEqual(summary.current.miles, 0)
        XCTAssertEqual(summary.buckets.count, 7)
        XCTAssertEqual(summary.title, "Week of Oct 26, 2026")
        XCTAssertEqual(summary.dateRangeText, "Oct 26 – Nov 1, 2026")
    }

    // MARK: Workout list

    func testPeriodWorkoutsBoundariesAndNewestFirst() {
        let priorSunday = ride(date(2026, 11, 1, 23, 59), 1)
        let weekStartMonday = ride(date(2026, 11, 2, 0, 0), 2)
        let thursdayRide = ride(date(2026, 11, 5, 7), 3)
        let weekEndSunday = ride(date(2026, 11, 8, 23, 59), 4)
        let nextMonday = ride(date(2026, 11, 9, 0, 0), 5)
        let list = PeriodSummary.calendarWorkouts([thursdayRide, nextMonday, priorSunday, weekEndSunday, weekStartMonday], period: .week, containing: date(2026, 11, 4), calendar: calendar)
        XCTAssertEqual(list.map(\.distanceMiles), [4, 3, 2])
        let periodSummary = summary([thursdayRide, nextMonday, priorSunday, weekEndSunday, weekStartMonday], .week, date(2026, 11, 4))
        XCTAssertEqual(periodSummary.current.count, list.count)
        XCTAssertEqual(periodSummary.current.miles, list.reduce(0) { $0 + $1.distanceMiles }, accuracy: 0.001)
    }

    func testPeriodWorkoutsFollowNavigation() {
        let rides = [ride(date(2026, 10, 30), 1), ride(date(2026, 11, 3), 2), ride(date(2026, 12, 2), 3)]
        var selection = self.selection(.month, date(2026, 11, 15))
        XCTAssertEqual(PeriodSummary.calendarWorkouts(rides, period: .month, containing: selection.start, calendar: calendar).map(\.distanceMiles), [2])
        selection = selection.moved(by: -1, calendar: calendar)
        XCTAssertEqual(PeriodSummary.calendarWorkouts(rides, period: .month, containing: selection.start, calendar: calendar).map(\.distanceMiles), [1])
        selection = selection.moved(by: 2, calendar: calendar)
        XCTAssertEqual(PeriodSummary.calendarWorkouts(rides, period: .month, containing: selection.start, calendar: calendar).map(\.distanceMiles), [3])
        selection = selection.moved(by: 1, calendar: calendar)                   // January 2027: empty
        XCTAssertTrue(PeriodSummary.calendarWorkouts(rides, period: .month, containing: selection.start, calendar: calendar).isEmpty)
        XCTAssertEqual(summary(rides, .month, selection.start).current.count, 0)
    }

    func testPeriodWorkoutsAcrossDSTWeek() {
        let late = ride(date(2026, 11, 1, 23, 30), 6)           // after fall-back, still Sun Nov 1
        let list = PeriodSummary.calendarWorkouts([late], period: .week, containing: date(2026, 10, 27), calendar: calendar)
        XCTAssertEqual(list.count, 1)
    }

    // MARK: Previous bound (earliest workout) and clamping

    func testPreviousStopsAtEarliestWorkoutsWeek() {
        let earliest = date(2026, 9, 16, 7)                          // Wed; its week starts Mon Sep 14
        let first = selection(.week, earliest)
        XCTAssertEqual(first.start, date(2026, 9, 14, 0))
        XCTAssertFalse(first.hasPrevious(earliest: earliest, calendar: calendar))
        XCTAssertTrue(first.moved(by: 1, calendar: calendar).hasPrevious(earliest: earliest, calendar: calendar))
        // Empty weeks between the earliest ride and now remain reachable.
        XCTAssertTrue(selection(.week, date(2026, 10, 5)).hasPrevious(earliest: earliest, calendar: calendar))
    }

    func testPreviousStopsAtEarliestMonthAndYear() {
        let earliest = date(2025, 3, 31, 23, 30)
        XCTAssertFalse(selection(.month, date(2025, 3, 1)).hasPrevious(earliest: earliest, calendar: calendar))
        XCTAssertTrue(selection(.month, date(2025, 4, 1)).hasPrevious(earliest: earliest, calendar: calendar))
        XCTAssertFalse(selection(.year, date(2025, 7, 1)).hasPrevious(earliest: earliest, calendar: calendar))
        XCTAssertTrue(selection(.year, date(2026, 1, 1)).hasPrevious(earliest: earliest, calendar: calendar))
    }

    func testNoWorkoutsDisablesPrevious() {
        XCTAssertFalse(selection(.week, date(2026, 11, 4)).hasPrevious(earliest: nil, calendar: calendar))
    }

    func testClampKeepsSelectionWithinEarliestAndCurrent() {
        let now = date(2026, 11, 4)
        let earliest = date(2026, 6, 10)
        // Before the earliest ride's month → clamped up to June.
        XCTAssertEqual(selection(.month, date(2026, 2, 3)).clamped(earliest: earliest, now: now, calendar: calendar).start, date(2026, 6, 1, 0))
        // Future → clamped down to the current month.
        XCTAssertEqual(selection(.month, date(2027, 1, 3)).clamped(earliest: earliest, now: now, calendar: calendar).start, date(2026, 11, 1, 0))
        // Inside → unchanged.
        let inside = selection(.month, date(2026, 8, 20))
        XCTAssertEqual(inside.clamped(earliest: earliest, now: now, calendar: calendar), inside)
        // No workouts → only the future bound applies.
        XCTAssertEqual(inside.clamped(earliest: nil, now: now, calendar: calendar), inside)
    }

    func testFilteredDatasetDrivesEarliest() {
        // Filtering out the oldest ride moves the Previous bound to the oldest remaining ride.
        let all = [ride(date(2026, 1, 5), 1, watts: 50), ride(date(2026, 8, 5), 2, watts: 120)]
        let filtered = all.filter { $0.avgWatts >= 100 }
        let earliest = filtered.map(\.date).min()
        XCTAssertFalse(selection(.month, date(2026, 8, 1)).hasPrevious(earliest: earliest, calendar: calendar))
        XCTAssertTrue(selection(.month, date(2026, 8, 1)).hasPrevious(earliest: all.map(\.date).min(), calendar: calendar))
    }

    func testCurrentPeriodHasNoNextAndEarliestEqualsCurrent() {
        let now = date(2026, 11, 4)
        let only = selection(.week, now)
        XCTAssertFalse(only.hasNext(now: now, calendar: calendar))
        XCTAssertFalse(only.hasPrevious(earliest: now, calendar: calendar))
    }
}
