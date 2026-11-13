import XCTest
@testable import FitnessTracker

final class PartialPeriodComparisonTests: XCTestCase {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return Calendar.mondayFirst(calendar)
    }()

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        TestSupport.date(year: year, month: month, day: day, hour: hour, minute: minute, calendar: calendar)
    }

    func ride(_ date: Date, minutes: Double = 30, miles: Double = 10, calories: Int = 300, watts: Int = 100) -> Workout {
        TestSupport.ride(
            date: date,
            durationMinutes: minutes,
            distanceMiles: miles,
            calories: calories,
            elevationFeet: 0,
            avgRPM: 80,
            avgWatts: watts
        )
    }

    func windows(_ period: GroupingPeriod, _ now: Date) -> (current: DateInterval, previous: DateInterval) {
        PartialPeriodComparison.windows(period: period, now: now, calendar: calendar)
    }

    // MARK: Week

    func testWeekAlignsMondayThroughSameWeekdayAndTime() {
        let periodWindows = windows(.week, date(2026, 11, 4, 15, 30)) // Wed
        XCTAssertEqual(periodWindows.current.start, date(2026, 11, 2))
        XCTAssertEqual(periodWindows.current.end, date(2026, 11, 4, 15, 30))
        XCTAssertEqual(periodWindows.previous.start, date(2026, 10, 26))
        XCTAssertEqual(periodWindows.previous.end, date(2026, 10, 28, 15, 30))
    }

    func testWeekSundayIsLastDayOfMondayFirstWeek() {
        let periodWindows = windows(.week, date(2026, 11, 8, 9))
        XCTAssertEqual(periodWindows.current.start, date(2026, 11, 2))
        XCTAssertEqual(periodWindows.previous.end, date(2026, 11, 1, 9))
    }

    func testWeekAcrossDSTUsesWallClock() {
        // DST began Sun Mar 8 2026 (US). Current week has no change; previous week contains it.
        let periodWindows = windows(.week, date(2026, 3, 15, 15))
        XCTAssertEqual(periodWindows.previous.start, date(2026, 3, 2))
        XCTAssertEqual(periodWindows.previous.end, date(2026, 3, 8, 15))
        // Current week contains the fall-back change (Nov 1 2026): previous week ends at the same wall time.
        let fallBackWindows = windows(.week, date(2026, 11, 1, 15))
        XCTAssertEqual(fallBackWindows.current.start, date(2026, 10, 26))
        XCTAssertEqual(fallBackWindows.previous.end, date(2026, 10, 25, 15))
    }

    func testWeekAcrossYearBoundary() {
        let periodWindows = windows(.week, date(2027, 1, 1, 12)) // Fri; week began Mon Dec 28 2026
        XCTAssertEqual(periodWindows.current.start, date(2026, 12, 28))
        XCTAssertEqual(periodWindows.previous.start, date(2026, 12, 21))
        XCTAssertEqual(periodWindows.previous.end, date(2026, 12, 25, 12))
    }

    // MARK: Month

    func testMonthSameDayOfMonth() {
        let periodWindows = windows(.month, date(2026, 3, 20, 15))
        XCTAssertEqual(periodWindows.previous.start, date(2026, 2, 1))
        XCTAssertEqual(periodWindows.previous.end, date(2026, 2, 20, 15))
    }

    func testMonthClipsToShorterPreviousMonth() {
        XCTAssertEqual(windows(.month, date(2026, 3, 31, 10)).previous.end, date(2026, 3, 1))
        XCTAssertEqual(windows(.month, date(2026, 3, 29, 10)).previous.end, date(2026, 3, 1))
        XCTAssertEqual(windows(.month, date(2026, 3, 28, 10)).previous.end, date(2026, 2, 28, 10))
        XCTAssertEqual(windows(.month, date(2028, 3, 29, 10)).previous.end, date(2028, 2, 29, 10)) // leap year
    }

    func testMonthAcrossYearBoundary() {
        let periodWindows = windows(.month, date(2027, 1, 10, 8))
        XCTAssertEqual(periodWindows.previous.start, date(2026, 12, 1))
        XCTAssertEqual(periodWindows.previous.end, date(2026, 12, 10, 8))
    }

    func testMonthAcrossDST() {
        let periodWindows = windows(.month, date(2026, 4, 10, 15)) // March contains DST start
        XCTAssertEqual(periodWindows.previous.end, date(2026, 3, 10, 15))
    }

    // MARK: Year

    func testYearSameMonthAndDay() {
        let periodWindows = windows(.year, date(2026, 3, 15, 12))
        XCTAssertEqual(periodWindows.previous.start, date(2025, 1, 1))
        XCTAssertEqual(periodWindows.previous.end, date(2025, 3, 15, 12))
    }

    func testYearLeapDayClipsToEndOfFebruary() {
        XCTAssertEqual(windows(.year, date(2028, 2, 29, 12)).previous.end, date(2027, 3, 1))
        XCTAssertEqual(windows(.year, date(2029, 2, 28, 12)).previous.end, date(2028, 2, 28, 12))
    }

    // MARK: Totals

    func testTotalsUseOnlyMatchingWindowsAndExcludeLaterPriorDays() {
        let now = date(2026, 11, 4, 15) // Wed
        let workouts = [
            ride(date(2026, 11, 2, 7)), ride(date(2026, 11, 4, 14)),   // current
            ride(date(2026, 10, 26, 7), minutes: 60),                  // previous, in window
            ride(date(2026, 10, 28, 16)),                              // previous, after same time -> excluded
            ride(date(2026, 10, 30, 7)),                               // later in prior week -> excluded
            ride(date(2026, 10, 19, 7)),                               // older
        ]
        let comparison = PartialPeriodComparison(workouts: workouts, period: .week, now: now, calendar: calendar)
        XCTAssertEqual(comparison.currentTotals.count, 2)
        XCTAssertEqual(comparison.previousTotals.count, 1)
        XCTAssertEqual(comparison.previousTotals.minutes, 60)
    }

    func testNoPriorDataAndMissingWatts() {
        let now = date(2026, 11, 4, 15)
        let comparison = PartialPeriodComparison(workouts: [ride(date(2026, 11, 3), watts: 0)], period: .week, now: now, calendar: calendar)
        XCTAssertEqual(comparison.previousTotals.count, 0)
        XCTAssertNil(comparison.previousTotals.averageWatts)
        XCTAssertNil(comparison.currentTotals.averageWatts)
        XCTAssertEqual(comparison.currentTotals.count, 1)
    }

    func testStartOfPeriodGivesEmptyWindows() {
        let periodWindows = windows(.week, date(2026, 11, 2))
        XCTAssertEqual(periodWindows.current.duration, 0)
        XCTAssertEqual(periodWindows.previous.duration, 0)
    }

    // MARK: Completed periods

    func testCompletedStartsExcludeCurrentPeriod() {
        let starts = [date(2026, 10, 19), date(2026, 10, 26), date(2026, 11, 2)]
        XCTAssertEqual(TrendsData.completedStarts(starts, period: .week, now: date(2026, 11, 4), calendar: calendar),
                       [date(2026, 10, 19), date(2026, 10, 26)])
    }
}
