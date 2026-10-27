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

    // Thu Oct 22, 2026 (noon, New York). Rolling windows end at midnight tonight:
    // Week  = Fri Oct 16 … Thu Oct 22, prior = Oct 9 … Oct 15
    // Month = Wed Sep 23 … Oct 22,     prior = Aug 24 … Sep 22
    // Year  = Fri Oct 23 2025 … Oct 22 2026
    lazy var now = date(2026, 10, 22)

    lazy var rides: [Workout] = [
        ride(date(2026, 10, 12, 14), 10.02),          // prior 7 days
        ride(date(2026, 10, 15, 12), 13.88),          // prior 7 days
        ride(date(2026, 10, 18, 15), 9.50),           // last 7 days
        ride(date(2026, 10, 20, 16), 9.85, minutes: 48, cal: 376, ft: 1542), // last 7 days
        ride(date(2026, 9, 30), 5.0),                 // last 30 days
        ride(date(2025, 12, 31, 23), 20.0),           // last 365 days only
    ]

    func testWeekTotalsAndDelta() {
        let s = PeriodSummary.compute(rides, period: .week, now: now, calendar: cal)
        XCTAssertEqual(s.interval.start, date(2026, 10, 16, 0))
        XCTAssertEqual(s.interval.end, date(2026, 10, 23, 0))
        XCTAssertEqual(s.current.count, 2)
        XCTAssertEqual(s.current.miles, 19.35, accuracy: 0.001)
        XCTAssertEqual(s.current.minutes, 78)
        XCTAssertEqual(s.current.calories, 676)
        XCTAssertEqual(s.current.feet, 2042)
        XCTAssertEqual(s.previous.count, 2) // Oct 12 and Oct 15
        XCTAssertEqual(s.previous.miles, 23.90, accuracy: 0.001)
        XCTAssertEqual(s.milesDelta, -4.55, accuracy: 0.001)
        XCTAssertEqual(s.deltaText, "−4.5 mi vs prior 7 days")
        XCTAssertEqual(s.title, "Last 7 Days")
    }

    func testWeekBucketsAreSevenDaysEndingToday() {
        let s = PeriodSummary.compute(rides, period: .week, now: now, calendar: cal)
        XCTAssertEqual(s.buckets.count, 7)
        XCTAssertEqual(s.buckets.first?.start, date(2026, 10, 16, 0))
        XCTAssertEqual(s.buckets.last?.start, date(2026, 10, 22, 0))
        XCTAssertEqual(s.buckets[2].miles, 9.50, accuracy: 0.001)  // Sun Oct 18
        XCTAssertEqual(s.buckets[4].miles, 9.85, accuracy: 0.001)  // Tue Oct 20
        XCTAssertEqual(s.buckets.compactMap(\.label), ["F", "S", "S", "M", "T", "W", "T"])
        XCTAssertEqual(s.buckets.reduce(0) { $0 + $1.miles }, s.current.miles, accuracy: 0.001)
    }

    func testMonthIsLast30Days() {
        let s = PeriodSummary.compute(rides, period: .month, now: now, calendar: cal)
        XCTAssertEqual(s.interval.start, date(2026, 9, 23, 0))
        XCTAssertEqual(s.current.count, 5)
        XCTAssertEqual(s.current.miles, 48.25, accuracy: 0.001)
        XCTAssertEqual(s.previous.count, 0)
        XCTAssertEqual(s.title, "Last 30 Days")
        XCTAssertEqual(s.deltaText, "+48.2 mi vs prior 30 days")
    }

    func testMonthBucketsDailyLabeledWeeklyFromToday() {
        let s = PeriodSummary.compute(rides, period: .month, now: now, calendar: cal)
        XCTAssertEqual(s.buckets.count, 30)
        XCTAssertEqual(s.buckets.last?.start, date(2026, 10, 22, 0))
        XCTAssertEqual(s.buckets.compactMap(\.label), ["24", "1", "8", "15", "22"])
        XCTAssertEqual(s.buckets.last?.label, "22")
        XCTAssertEqual(s.buckets.reduce(0) { $0 + $1.miles }, s.current.miles, accuracy: 0.001)
    }

    func testYearIsLast365DaysWithTwelveMonthlyBuckets() {
        let s = PeriodSummary.compute(rides, period: .year, now: now, calendar: cal)
        XCTAssertEqual(s.interval.start, date(2025, 10, 23, 0))
        XCTAssertEqual(s.current.count, 6)
        XCTAssertEqual(s.current.miles, 68.25, accuracy: 0.001)
        XCTAssertEqual(s.title, "Last 365 Days")
        XCTAssertEqual(s.buckets.count, 12)
        XCTAssertEqual(s.buckets.first?.start, s.interval.start)      // first bar absorbs Oct 23–31, 2025
        XCTAssertEqual(s.buckets.first?.end, date(2025, 12, 1, 0))
        XCTAssertEqual(s.buckets.last?.start, date(2026, 10, 1, 0))
        XCTAssertEqual(s.buckets[11].miles, 43.25, accuracy: 0.001) // October 2026
        XCTAssertEqual(s.buckets[10].miles, 5.0, accuracy: 0.001)   // September
        XCTAssertEqual(s.buckets[1].miles, 20.0, accuracy: 0.001)   // December 2025
        XCTAssertEqual(s.buckets.compactMap(\.label), ["J", "A", "J", "O"])
        XCTAssertEqual(s.buckets.reduce(0) { $0 + $1.miles }, s.current.miles, accuracy: 0.001)
    }

    func testEmptyAndZeroDelta() {
        let s = PeriodSummary.compute([], period: .week, now: now, calendar: cal)
        XCTAssertEqual(s.current.count, 0)
        XCTAssertEqual(s.milesDelta, 0)
        XCTAssertEqual(s.deltaText, "±0.0 mi vs prior 7 days")
    }

    func testWindowBoundariesAtMidnight() {
        let startOfWindow = date(2026, 10, 16, 0)
        let justBefore = startOfWindow.addingTimeInterval(-60)
        let lateToday = date(2026, 10, 22, 23)
        let s = PeriodSummary.compute([ride(startOfWindow, 3), ride(justBefore, 4), ride(lateToday, 5)],
                                      period: .week, now: now, calendar: cal)
        XCTAssertEqual(s.current.count, 2)   // midnight Oct 16 and late today
        XCTAssertEqual(s.previous.count, 1)  // 11:59 PM Oct 15
    }

    func testWeekAcrossDSTUsesCalendarDays() {
        // DST ends Sun Nov 1, 2026 in New York; the window still covers 7 calendar days.
        let s = PeriodSummary.compute([], period: .week, now: date(2026, 11, 3), calendar: cal)
        XCTAssertEqual(s.interval.start, date(2026, 10, 28, 0))
        XCTAssertEqual(s.interval.end, date(2026, 11, 4, 0))
        XCTAssertEqual(s.buckets.count, 7)
        XCTAssertEqual(s.buckets.map { cal.component(.day, from: $0.start) }, [28, 29, 30, 31, 1, 2, 3])
    }

    func testPerMetricDeltasWeek() {
        // Last 7 days: 2 rides, 78 min, 676 cal, 2042 ft. Prior 7: 2 rides, 60 min, 600 cal, 1000 ft.
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

final class MondayWeekTests: XCTestCase {
    /// A base calendar whose locale would normally start weeks on Sunday.
    var usCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_US")
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 12) -> Date {
        usCalendar.date(from: DateComponents(year: y, month: m, day: day, hour: h))!
    }

    func testMondayFirstOverridesLocale() {
        XCTAssertEqual(usCalendar.firstWeekday, 1)
        let cal = Calendar.mondayFirst(usCalendar)
        XCTAssertEqual(cal.firstWeekday, 2)
        XCTAssertEqual(cal.minimumDaysInFirstWeek, 4)
        XCTAssertEqual(cal.timeZone, usCalendar.timeZone)
        XCTAssertEqual(Calendar.app.firstWeekday, 2)
    }

    func testWeekGroupingStartsMonday() {
        let cal = Calendar.mondayFirst(usCalendar)
        // Oct 2026: Mon 19 … Sun 25, Mon 26.
        XCTAssertEqual(GroupingPeriod.week.start(of: d(2026, 10, 25), calendar: cal), d(2026, 10, 19, 0)) // Sunday → previous Monday
        XCTAssertEqual(GroupingPeriod.week.start(of: d(2026, 10, 26), calendar: cal), d(2026, 10, 26, 0)) // Monday → itself
        XCTAssertEqual(GroupingPeriod.week.start(of: d(2026, 10, 21), calendar: cal), d(2026, 10, 19, 0))
        // Sunday and the following Monday land in different sections.
        XCTAssertNotEqual(GroupingPeriod.week.start(of: d(2026, 10, 25, 23), calendar: cal),
                          GroupingPeriod.week.start(of: d(2026, 10, 26, 0), calendar: cal))
    }

    func testWeekLabelShowsMonday() {
        let cal = Calendar.mondayFirst(usCalendar)
        let start = GroupingPeriod.week.start(of: d(2026, 10, 25), calendar: cal)
        XCTAssertTrue(GroupingPeriod.week.label(for: start, calendar: cal).hasPrefix("Week of Oct 19"))
    }

    func testISOWeekNumbering() {
        let cal = Calendar.mondayFirst(usCalendar)
        // Jan 1, 2027 is a Friday, so ISO week 1 of 2027 starts Mon Jan 4; Jan 1 is in week 53 of 2026.
        XCTAssertEqual(cal.component(.weekOfYear, from: d(2027, 1, 1)), 53)
        XCTAssertEqual(cal.component(.weekOfYear, from: d(2027, 1, 4)), 1)
    }

    func testDefaultUsesAppCalendar() {
        // Without an explicit calendar, grouping uses Calendar.app (Monday-first) on any device.
        let sunday = Calendar.app.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12))!
        let start = GroupingPeriod.week.start(of: sunday)
        XCTAssertEqual(Calendar.app.component(.weekday, from: start), 2)
    }
}

final class WattsRPMTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()
    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }
    func ride(_ d: Date, minutes: Double, watts: Int, rpm: Int) -> Workout {
        Workout(date: d, program: nil, durationMinutes: minutes, distanceMiles: 10, calories: 300,
                elevationFeet: 500, avgRPM: rpm, avgWatts: watts, inclineAvg: 0, inclineMax: 0,
                resistanceAvg: 10, resistanceMax: 15)
    }
    lazy var now = date(2026, 10, 22)

    func testTimeWeightedAverages() {
        // 60 min @ 100 W / 80 rpm and 30 min @ 70 W / 74 rpm → (6000+2100)/90 = 90 W, (4800+2220)/90 = 78 rpm.
        let t = Totals([ride(now, minutes: 60, watts: 100, rpm: 80), ride(now, minutes: 30, watts: 70, rpm: 74)])
        XCTAssertEqual(t.averageWatts ?? -1, 90, accuracy: 0.001)
        XCTAssertEqual(t.averageRPM ?? -1, 78, accuracy: 0.001)
    }

    func testRidesWithoutValueAreIgnored() {
        // A ride with 0 W / 0 rpm (not recorded) doesn't drag the average down.
        let t = Totals([ride(now, minutes: 45, watts: 88, rpm: 75), ride(now, minutes: 45, watts: 0, rpm: 0)])
        XCTAssertEqual(t.averageWatts ?? -1, 88, accuracy: 0.001)
        XCTAssertEqual(t.averageRPM ?? -1, 75, accuracy: 0.001)
    }

    func testSimpleMeanWhenNoDurations() {
        let t = Totals([ride(now, minutes: 0, watts: 80, rpm: 70), ride(now, minutes: 0, watts: 90, rpm: 80)])
        XCTAssertEqual(t.averageWatts ?? -1, 85, accuracy: 0.001)
        XCTAssertEqual(t.averageRPM ?? -1, 75, accuracy: 0.001)
    }

    func testMissingValuesShowDash() {
        let t = Totals([ride(now, minutes: 30, watts: 0, rpm: 0)])
        XCTAssertNil(t.averageWatts)
        XCTAssertNil(Totals([]).averageRPM)
        let s = PeriodSummary.compute([], period: .week, now: now, calendar: cal)
        XCTAssertEqual(s.valueText(.watts).value, "—")
        XCTAssertEqual(s.valueText(.rpm).value, "—")
        XCTAssertEqual(s.deltaText(.watts), "—")
        XCTAssertNil(s.wattsDelta)
        XCTAssertEqual(s.delta(.watts), 0)
    }

    func testDeltasVsPriorWindow() {
        let rides = [
            ride(date(2026, 10, 20), minutes: 48, watts: 88, rpm: 75),   // last 7 days
            ride(date(2026, 10, 18), minutes: 46, watts: 97, rpm: 74),   // last 7 days
            ride(date(2026, 10, 12), minutes: 42, watts: 79, rpm: 79),   // prior 7 days
        ]
        let s = PeriodSummary.compute(rides, period: .week, now: now, calendar: cal)
        // Current: (88*48 + 97*46)/94 = 92.4 → 92 W; (75*48 + 74*46)/94 = 74.5 → 75 rpm (rounded)
        XCTAssertEqual(s.valueText(.watts).value, "92 W")
        XCTAssertEqual(s.valueText(.watts).label, "Watts")
        XCTAssertEqual(s.valueText(.rpm).label, "RPM")
        XCTAssertEqual(s.wattsDelta, 92 - 79)
        XCTAssertEqual(s.deltaText(.watts), "▲ 13 W")
        let rpm = Int(s.current.averageRPM!.rounded())
        XCTAssertEqual(s.rpmDelta, rpm - 79)
        XCTAssertEqual(s.deltaText(.rpm), "▼ \(79 - rpm) rpm")
    }

    func testNoPriorDataGivesDash() {
        let s = PeriodSummary.compute([ride(date(2026, 10, 20), minutes: 48, watts: 88, rpm: 75)],
                                      period: .week, now: now, calendar: cal)
        XCTAssertEqual(s.valueText(.watts).value, "88 W")
        XCTAssertEqual(s.valueText(.rpm).value, "75")
        XCTAssertEqual(s.deltaText(.watts), "—")
        XCTAssertEqual(s.deltaText(.rpm), "—")
    }

    func testMetricOrder() {
        XCTAssertEqual(PeriodSummary.Metric.allCases, [.rides, .time, .watts, .rpm, .elevation, .calories])
    }
}
