import XCTest
@testable import FitnessTracker

final class PeriodSummaryTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        c.firstWeekday = 1 // Sunday
        return c
    }()

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func ride(_ d: Date, _ miles: Double, minutes: Double = 30, cal calories: Int = 300, ft: Int = 500) -> Workout {
        Workout(date: d, program: nil, durationMinutes: minutes, distanceMiles: miles, calories: calories,
                elevationFeet: ft, avgRPM: 75, avgWatts: 85, inclineAvg: 0, inclineMax: 0,
                resistanceAvg: 10, resistanceMax: 15)
    }

    // Thu Oct 22, 2026; week = Sun Oct 18 ... Sat Oct 24
    lazy var now = date(2026, 10, 22)

    lazy var rides: [Workout] = [
        ride(date(2026, 10, 12, 14), 10.02),          // previous week
        ride(date(2026, 10, 15, 12), 13.88),          // previous week
        ride(date(2026, 10, 18, 15), 9.50),           // this week (Sun)
        ride(date(2026, 10, 20, 16), 9.85, minutes: 48, cal: 376, ft: 1542), // this week (Tue)
        ride(date(2026, 9, 30), 5.0),                 // previous month
        ride(date(2025, 12, 31, 23), 20.0),           // previous year
    ]

    func testWeekTotalsAndDelta() {
        let s = PeriodSummary.compute(rides, period: .week, now: now, calendar: cal)
        XCTAssertEqual(s.current.count, 2)
        XCTAssertEqual(s.current.miles, 19.35, accuracy: 0.001)
        XCTAssertEqual(s.current.minutes, 78)
        XCTAssertEqual(s.current.calories, 676)
        XCTAssertEqual(s.current.feet, 2042)
        XCTAssertEqual(s.previous.count, 2) // Oct 12 (Mon) and Oct 15 (Thu)
        XCTAssertEqual(s.previous.miles, 23.90, accuracy: 0.001)
        XCTAssertEqual(s.milesDelta, -4.55, accuracy: 0.001)
        XCTAssertEqual(s.deltaText, "−4.5 mi vs last week")
        XCTAssertEqual(s.title, "This Week")
    }

    func testWeekBucketsAreSevenDays() {
        let s = PeriodSummary.compute(rides, period: .week, now: now, calendar: cal)
        XCTAssertEqual(s.buckets.count, 7)
        XCTAssertEqual(s.buckets[0].miles, 9.50, accuracy: 0.001)  // Sunday
        XCTAssertEqual(s.buckets[2].miles, 9.85, accuracy: 0.001)  // Tuesday
        XCTAssertEqual(s.buckets.reduce(0) { $0 + $1.miles }, s.current.miles, accuracy: 0.001)
    }

    func testMonthTotalsAndDelta() {
        let s = PeriodSummary.compute(rides, period: .month, now: now, calendar: cal)
        XCTAssertEqual(s.current.count, 4)
        XCTAssertEqual(s.current.miles, 43.25, accuracy: 0.001)
        XCTAssertEqual(s.previous.miles, 5.0, accuracy: 0.001)
        XCTAssertEqual(s.buckets.count, 31)
        XCTAssertTrue(s.deltaText.hasPrefix("+38.2"))
        XCTAssertTrue(s.deltaText.hasSuffix("vs last month"))
    }

    func testYearBucketsAndPreviousYear() {
        let s = PeriodSummary.compute(rides, period: .year, now: now, calendar: cal)
        XCTAssertEqual(s.current.count, 5)
        XCTAssertEqual(s.previous.count, 1)
        XCTAssertEqual(s.previous.miles, 20.0, accuracy: 0.001)
        XCTAssertEqual(s.buckets.count, 12)
        XCTAssertEqual(s.buckets[9].miles, 43.25, accuracy: 0.001) // October
        XCTAssertEqual(s.buckets[8].miles, 5.0, accuracy: 0.001)   // September
    }

    func testEmptyAndZeroDelta() {
        let s = PeriodSummary.compute([], period: .week, now: now, calendar: cal)
        XCTAssertEqual(s.current.count, 0)
        XCTAssertEqual(s.milesDelta, 0)
        XCTAssertEqual(s.deltaText, "±0.0 mi vs last week")
    }

    func testBoundaryMidnightBelongsToNewPeriod() {
        let sundayMidnight = cal.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 0))!
        let s = PeriodSummary.compute([ride(sundayMidnight, 3)], period: .week, now: now, calendar: cal)
        XCTAssertEqual(s.current.count, 1)
        XCTAssertEqual(s.previous.count, 0)
    }

    func testPerMetricDeltasWeek() {
        // This week: 2 rides, 78 min, 676 cal, 2042 ft. Last week: 2 rides, 60 min, 600 cal, 1000 ft.
        let s = PeriodSummary.compute(rides, period: .week, now: now, calendar: cal)
        XCTAssertEqual(s.ridesDelta, 0)
        XCTAssertEqual(s.minutesDelta, 18)
        XCTAssertEqual(s.caloriesDelta, 76)
        XCTAssertEqual(s.feetDelta, 1042)
        XCTAssertEqual(s.deltaText(.rides), "– 0")
        XCTAssertEqual(s.deltaText(.time), "▲ 18m")
        XCTAssertEqual(s.deltaText(.calories), "▲ 76 cal")
        XCTAssertEqual(s.deltaText(.elevation), "▲ 1042 ft")
    }

    func testPerMetricDeltasDownAndHours() {
        let s = PeriodSummary.compute([ride(date(2026, 10, 14), 20, minutes: 95, cal: 800, ft: 900)],
                                      period: .week, now: now, calendar: cal)
        XCTAssertEqual(s.ridesDelta, -1)
        XCTAssertEqual(s.deltaText(.rides), "▼ 1")
        XCTAssertEqual(s.deltaText(.time), "▼ 1h 35m")
        XCTAssertEqual(s.deltaText(.calories), "▼ 800 cal")
        XCTAssertEqual(s.deltaText(.elevation), "▼ 900 ft")
        XCTAssertLessThan(s.delta(.time), 0)
    }

    func testMilesNumberFormatting() {
        let us = Locale(identifier: "en_US")
        XCTAssertEqual(PeriodSummary.milesNumber(9.85, locale: us), "9.8")   // banker's rounding of 9.85 (binary 9.8499…)
        XCTAssertEqual(PeriodSummary.milesNumber(43.25, locale: us), "43.2")
        XCTAssertEqual(PeriodSummary.milesNumber(99.9, locale: us), "99.9")
        XCTAssertEqual(PeriodSummary.milesNumber(99.96, locale: us), "100")
        XCTAssertEqual(PeriodSummary.milesNumber(100.4, locale: us), "100")
        XCTAssertEqual(PeriodSummary.milesNumber(1234.5, locale: us), "1,235")
        XCTAssertEqual(PeriodSummary.milesNumber(0, locale: us), "0.0")
    }

    func testDeltaTextUsesWholeMilesAt100() {
        let big = (1...12).map { ride(date(2026, 10, $0), 10) }   // 120 mi this month (Oct 1–12), 0 last month
        let s = PeriodSummary.compute(big, period: .month, now: now, calendar: cal)
        XCTAssertEqual(s.current.miles, 120, accuracy: 0.001)
        XCTAssertTrue(s.deltaText.hasPrefix("+120 mi"), s.deltaText)
    }
}
