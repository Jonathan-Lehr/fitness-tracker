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
}
