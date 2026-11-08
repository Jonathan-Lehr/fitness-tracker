import XCTest
@testable import FitnessTracker

final class PartialPeriodComparisonTests: XCTestCase {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return Calendar.mondayFirst(c)
    }()

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func ride(_ d: Date, minutes: Double = 30, miles: Double = 10, cal calories: Int = 300, watts: Int = 100) -> Workout {
        Workout(date: d, program: nil, durationMinutes: minutes, distanceMiles: miles, calories: calories,
                elevationFeet: 0, avgRPM: 80, avgWatts: watts, inclineAvg: 0, inclineMax: 0,
                resistanceAvg: 10, resistanceMax: 15)
    }

    func windows(_ p: GroupingPeriod, _ now: Date) -> (current: DateInterval, previous: DateInterval) {
        PartialPeriodComparison.windows(period: p, now: now, calendar: cal)
    }

    // MARK: Week

    func testWeekAlignsMondayThroughSameWeekdayAndTime() {
        let w = windows(.week, date(2026, 11, 4, 15, 30)) // Wed
        XCTAssertEqual(w.current.start, date(2026, 11, 2))
        XCTAssertEqual(w.current.end, date(2026, 11, 4, 15, 30))
        XCTAssertEqual(w.previous.start, date(2026, 10, 26))
        XCTAssertEqual(w.previous.end, date(2026, 10, 28, 15, 30))
    }

    func testWeekSundayIsLastDayOfMondayFirstWeek() {
        let w = windows(.week, date(2026, 11, 8, 9))
        XCTAssertEqual(w.current.start, date(2026, 11, 2))
        XCTAssertEqual(w.previous.end, date(2026, 11, 1, 9))
    }

    func testWeekAcrossDSTUsesWallClock() {
        // DST began Sun Mar 8 2026 (US). Current week has no change; previous week contains it.
        let w = windows(.week, date(2026, 3, 15, 15))
        XCTAssertEqual(w.previous.start, date(2026, 3, 2))
        XCTAssertEqual(w.previous.end, date(2026, 3, 8, 15))
        // Current week contains the fall-back change (Nov 1 2026): previous week ends at the same wall time.
        let f = windows(.week, date(2026, 11, 1, 15))
        XCTAssertEqual(f.current.start, date(2026, 10, 26))
        XCTAssertEqual(f.previous.end, date(2026, 10, 25, 15))
    }

    func testWeekAcrossYearBoundary() {
        let w = windows(.week, date(2027, 1, 1, 12)) // Fri; week began Mon Dec 28 2026
        XCTAssertEqual(w.current.start, date(2026, 12, 28))
        XCTAssertEqual(w.previous.start, date(2026, 12, 21))
        XCTAssertEqual(w.previous.end, date(2026, 12, 25, 12))
    }

    // MARK: Month

    func testMonthSameDayOfMonth() {
        let w = windows(.month, date(2026, 3, 20, 15))
        XCTAssertEqual(w.previous.start, date(2026, 2, 1))
        XCTAssertEqual(w.previous.end, date(2026, 2, 20, 15))
    }

    func testMonthClipsToShorterPreviousMonth() {
        XCTAssertEqual(windows(.month, date(2026, 3, 31, 10)).previous.end, date(2026, 3, 1))
        XCTAssertEqual(windows(.month, date(2026, 3, 29, 10)).previous.end, date(2026, 3, 1))
        XCTAssertEqual(windows(.month, date(2026, 3, 28, 10)).previous.end, date(2026, 2, 28, 10))
        XCTAssertEqual(windows(.month, date(2028, 3, 29, 10)).previous.end, date(2028, 2, 29, 10)) // leap year
    }

    func testMonthAcrossYearBoundary() {
        let w = windows(.month, date(2027, 1, 10, 8))
        XCTAssertEqual(w.previous.start, date(2026, 12, 1))
        XCTAssertEqual(w.previous.end, date(2026, 12, 10, 8))
    }

    func testMonthAcrossDST() {
        let w = windows(.month, date(2026, 4, 10, 15)) // March contains DST start
        XCTAssertEqual(w.previous.end, date(2026, 3, 10, 15))
    }

    // MARK: Year

    func testYearSameMonthAndDay() {
        let w = windows(.year, date(2026, 3, 15, 12))
        XCTAssertEqual(w.previous.start, date(2025, 1, 1))
        XCTAssertEqual(w.previous.end, date(2025, 3, 15, 12))
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
        let c = PartialPeriodComparison(workouts: workouts, period: .week, now: now, calendar: cal)
        XCTAssertEqual(c.currentTotals.count, 2)
        XCTAssertEqual(c.previousTotals.count, 1)
        XCTAssertEqual(c.previousTotals.minutes, 60)
    }

    func testNoPriorDataAndMissingWatts() {
        let now = date(2026, 11, 4, 15)
        let c = PartialPeriodComparison(workouts: [ride(date(2026, 11, 3), watts: 0)], period: .week, now: now, calendar: cal)
        XCTAssertEqual(c.previousTotals.count, 0)
        XCTAssertNil(c.previousTotals.averageWatts)
        XCTAssertNil(c.currentTotals.averageWatts)
        XCTAssertEqual(c.currentTotals.count, 1)
    }

    func testStartOfPeriodGivesEmptyWindows() {
        let w = windows(.week, date(2026, 11, 2))
        XCTAssertEqual(w.current.duration, 0)
        XCTAssertEqual(w.previous.duration, 0)
    }

    // MARK: Completed periods

    func testCompletedStartsExcludeCurrentPeriod() {
        let starts = [date(2026, 10, 19), date(2026, 10, 26), date(2026, 11, 2)]
        XCTAssertEqual(TrendsData.completedStarts(starts, period: .week, now: date(2026, 11, 4), calendar: cal),
                       [date(2026, 10, 19), date(2026, 10, 26)])
    }
}
