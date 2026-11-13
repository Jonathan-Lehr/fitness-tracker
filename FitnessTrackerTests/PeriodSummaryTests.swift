import XCTest
@testable import FitnessTracker

final class PeriodSummaryTests: XCTestCase {
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.firstWeekday = 1 // Sunday
        return calendar
    }()

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        TestSupport.date(year: year, month: month, day: day, hour: hour, calendar: calendar)
    }

    func ride(_ date: Date, _ miles: Double, minutes: Double = 30, calories: Int = 300, elevationFeet: Int = 500) -> Workout {
        TestSupport.ride(
            date: date,
            durationMinutes: minutes,
            distanceMiles: miles,
            calories: calories,
            elevationFeet: elevationFeet
        )
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
        ride(date(2026, 10, 20, 16), 9.85, minutes: 48, calories: 376, elevationFeet: 1542), // last 7 days
        ride(date(2026, 9, 30), 5.0),                 // last 30 days
        ride(date(2025, 12, 31, 23), 20.0),           // last 365 days only
    ]

    func testWeekTotalsAndDelta() {
        let summary = PeriodSummary.compute(rides, period: .week, now: now, calendar: calendar)
        XCTAssertEqual(summary.interval.start, date(2026, 10, 16, 0))
        XCTAssertEqual(summary.interval.end, date(2026, 10, 23, 0))
        XCTAssertEqual(summary.current.count, 2)
        XCTAssertEqual(summary.current.miles, 19.35, accuracy: 0.001)
        XCTAssertEqual(summary.current.minutes, 78)
        XCTAssertEqual(summary.current.calories, 676)
        XCTAssertEqual(summary.current.feet, 2042)
        XCTAssertEqual(summary.previous.count, 2) // Oct 12 and Oct 15
        XCTAssertEqual(summary.previous.miles, 23.90, accuracy: 0.001)
        XCTAssertEqual(summary.milesDelta, -4.55, accuracy: 0.001)
        XCTAssertEqual(summary.deltaText, "−4.5 mi vs prior 7 days")
        XCTAssertEqual(summary.title, "Last 7 Days")
    }

    func testWeekBucketsAreSevenDaysEndingToday() {
        let summary = PeriodSummary.compute(rides, period: .week, now: now, calendar: calendar)
        XCTAssertEqual(summary.buckets.count, 7)
        XCTAssertEqual(summary.buckets.first?.start, date(2026, 10, 16, 0))
        XCTAssertEqual(summary.buckets.last?.start, date(2026, 10, 22, 0))
        XCTAssertEqual(summary.buckets[2].miles, 9.50, accuracy: 0.001)  // Sun Oct 18
        XCTAssertEqual(summary.buckets[4].miles, 9.85, accuracy: 0.001)  // Tue Oct 20
        XCTAssertEqual(summary.buckets.compactMap(\.label), ["F", "S", "S", "M", "T", "W", "T"])
        XCTAssertEqual(summary.buckets.reduce(0) { $0 + $1.miles }, summary.current.miles, accuracy: 0.001)
    }

    func testMonthIsLast30Days() {
        let summary = PeriodSummary.compute(rides, period: .month, now: now, calendar: calendar)
        XCTAssertEqual(summary.interval.start, date(2026, 9, 23, 0))
        XCTAssertEqual(summary.current.count, 5)
        XCTAssertEqual(summary.current.miles, 48.25, accuracy: 0.001)
        XCTAssertEqual(summary.previous.count, 0)
        XCTAssertEqual(summary.title, "Last 30 Days")
        XCTAssertEqual(summary.deltaText, "+48.2 mi vs prior 30 days")
    }

    func testMonthBucketsDailyLabeledWeeklyFromToday() {
        let summary = PeriodSummary.compute(rides, period: .month, now: now, calendar: calendar)
        XCTAssertEqual(summary.buckets.count, 30)
        XCTAssertEqual(summary.buckets.last?.start, date(2026, 10, 22, 0))
        XCTAssertEqual(summary.buckets.compactMap(\.label), ["24", "1", "8", "15", "22"])
        XCTAssertEqual(summary.buckets.last?.label, "22")
        XCTAssertEqual(summary.buckets.reduce(0) { $0 + $1.miles }, summary.current.miles, accuracy: 0.001)
    }

    func testYearIsLast365DaysWithTwelveMonthlyBuckets() {
        let summary = PeriodSummary.compute(rides, period: .year, now: now, calendar: calendar)
        XCTAssertEqual(summary.interval.start, date(2025, 10, 23, 0))
        XCTAssertEqual(summary.current.count, 6)
        XCTAssertEqual(summary.current.miles, 68.25, accuracy: 0.001)
        XCTAssertEqual(summary.title, "Last 365 Days")
        XCTAssertEqual(summary.buckets.count, 12)
        XCTAssertEqual(summary.buckets.first?.start, summary.interval.start)      // first bar absorbs Oct 23–31, 2025
        XCTAssertEqual(summary.buckets.first?.end, date(2025, 12, 1, 0))
        XCTAssertEqual(summary.buckets.last?.start, date(2026, 10, 1, 0))
        XCTAssertEqual(summary.buckets[11].miles, 43.25, accuracy: 0.001) // October 2026
        XCTAssertEqual(summary.buckets[10].miles, 5.0, accuracy: 0.001)   // September
        XCTAssertEqual(summary.buckets[1].miles, 20.0, accuracy: 0.001)   // December 2025
        XCTAssertEqual(summary.buckets.compactMap(\.label), ["J", "A", "J", "O"])
        XCTAssertEqual(summary.buckets.reduce(0) { $0 + $1.miles }, summary.current.miles, accuracy: 0.001)
    }

    func testEmptyAndZeroDelta() {
        let summary = PeriodSummary.compute([], period: .week, now: now, calendar: calendar)
        XCTAssertEqual(summary.current.count, 0)
        XCTAssertEqual(summary.milesDelta, 0)
        XCTAssertEqual(summary.deltaText, "±0.0 mi vs prior 7 days")
    }

    func testWindowBoundariesAtMidnight() {
        let startOfWindow = date(2026, 10, 16, 0)
        let justBefore = startOfWindow.addingTimeInterval(-60)
        let lateToday = date(2026, 10, 22, 23)
        let summary = PeriodSummary.compute([ride(startOfWindow, 3), ride(justBefore, 4), ride(lateToday, 5)],
                                      period: .week, now: now, calendar: calendar)
        XCTAssertEqual(summary.current.count, 2)   // midnight Oct 16 and late today
        XCTAssertEqual(summary.previous.count, 1)  // 11:59 PM Oct 15
    }

    func testWeekAcrossDSTUsesCalendarDays() {
        // DST ends Sun Nov 1, 2026 in New York; the window still covers 7 calendar days.
        let summary = PeriodSummary.compute([], period: .week, now: date(2026, 11, 3), calendar: calendar)
        XCTAssertEqual(summary.interval.start, date(2026, 10, 28, 0))
        XCTAssertEqual(summary.interval.end, date(2026, 11, 4, 0))
        XCTAssertEqual(summary.buckets.count, 7)
        XCTAssertEqual(summary.buckets.map { calendar.component(.day, from: $0.start) }, [28, 29, 30, 31, 1, 2, 3])
    }

    func testPerMetricDeltasWeek() {
        // Last 7 days: 2 rides, 78 min, 676 cal, 2042 ft. Prior 7: 2 rides, 60 min, 600 cal, 1000 ft.
        let summary = PeriodSummary.compute(rides, period: .week, now: now, calendar: calendar)
        XCTAssertEqual(summary.ridesDelta, 0)
        XCTAssertEqual(summary.minutesDelta, 18)
        XCTAssertEqual(summary.caloriesDelta, 76)
        XCTAssertEqual(summary.feetDelta, 1042)
        let usLocale = Locale(identifier: "en_US")
        let german = Locale(identifier: "de_DE")
        XCTAssertEqual(summary.deltaText(.rides, locale: usLocale), "– 0")
        XCTAssertEqual(summary.deltaText(.time, locale: usLocale), "▲ 18m")
        XCTAssertEqual(summary.deltaText(.calories, locale: usLocale), "▲ 76 cal")
        XCTAssertEqual(summary.deltaText(.elevation, locale: usLocale), "▲ 1,042 ft")
        XCTAssertEqual(summary.deltaText(.elevation, locale: german), "▲ 1.042 ft")
        XCTAssertEqual(summary.valueText(.elevation, locale: usLocale).value, "2,042 ft")
        XCTAssertEqual(summary.valueText(.elevation, locale: german).value, "2.042 ft")
        XCTAssertEqual(summary.valueText(.calories, locale: usLocale).value, "676")
    }

    func testPerMetricDeltasDownAndHours() {
        let summary = PeriodSummary.compute([ride(date(2026, 10, 14), 20, minutes: 95, calories: 800, elevationFeet: 900)],
                                      period: .week, now: now, calendar: calendar)
        XCTAssertEqual(summary.ridesDelta, -1)
        XCTAssertEqual(summary.deltaText(.rides), "▼ 1")
        XCTAssertEqual(summary.deltaText(.time), "▼ 1h 35m")
        XCTAssertEqual(summary.deltaText(.calories), "▼ 800 cal")
        XCTAssertEqual(summary.deltaText(.elevation), "▼ 900 ft")
        XCTAssertLessThan(summary.delta(.time), 0)
    }

    func testMilesNumberFormatting() {
        let usLocale = Locale(identifier: "en_US")
        XCTAssertEqual(PeriodSummary.milesNumber(9.85, locale: usLocale), "9.8")   // banker's rounding of 9.85 (binary 9.8499…)
        XCTAssertEqual(PeriodSummary.milesNumber(43.25, locale: usLocale), "43.2")
        XCTAssertEqual(PeriodSummary.milesNumber(99.9, locale: usLocale), "99.9")
        XCTAssertEqual(PeriodSummary.milesNumber(99.96, locale: usLocale), "100")
        XCTAssertEqual(PeriodSummary.milesNumber(100.4, locale: usLocale), "100")
        XCTAssertEqual(PeriodSummary.milesNumber(1234.5, locale: usLocale), "1,235")
        XCTAssertEqual(PeriodSummary.milesNumber(0, locale: usLocale), "0.0")
    }

    func testDeltaTextUsesWholeMilesAt100() {
        let big = (1...12).map { ride(date(2026, 10, $0), 10) }   // 120 mi this month (Oct 1–12), 0 last month
        let summary = PeriodSummary.compute(big, period: .month, now: now, calendar: calendar)
        XCTAssertEqual(summary.current.miles, 120, accuracy: 0.001)
        XCTAssertTrue(summary.deltaText.hasPrefix("+120 mi"), summary.deltaText)
    }
}

final class MondayWeekTests: XCTestCase {
    /// A base calendar whose locale would normally start weeks on Sunday.
    var usCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        TestSupport.date(year: year, month: month, day: day, hour: hour, calendar: usCalendar)
    }

    func testMondayFirstOverridesLocale() {
        XCTAssertEqual(usCalendar.firstWeekday, 1)
        let calendar = Calendar.mondayFirst(usCalendar)
        XCTAssertEqual(calendar.firstWeekday, 2)
        XCTAssertEqual(calendar.minimumDaysInFirstWeek, 4)
        XCTAssertEqual(calendar.timeZone, usCalendar.timeZone)
        XCTAssertEqual(Calendar.app.firstWeekday, 2)
    }

    func testWeekGroupingStartsMonday() {
        let calendar = Calendar.mondayFirst(usCalendar)
        // Oct 2026: Mon 19 … Sun 25, Mon 26.
        XCTAssertEqual(GroupingPeriod.week.start(of: date(2026, 10, 25), calendar: calendar), date(2026, 10, 19, 0)) // Sunday → previous Monday
        XCTAssertEqual(GroupingPeriod.week.start(of: date(2026, 10, 26), calendar: calendar), date(2026, 10, 26, 0)) // Monday → itself
        XCTAssertEqual(GroupingPeriod.week.start(of: date(2026, 10, 21), calendar: calendar), date(2026, 10, 19, 0))
        // Sunday and the following Monday land in different sections.
        XCTAssertNotEqual(GroupingPeriod.week.start(of: date(2026, 10, 25, 23), calendar: calendar),
                          GroupingPeriod.week.start(of: date(2026, 10, 26, 0), calendar: calendar))
    }

    func testWeekLabelShowsMonday() {
        let calendar = Calendar.mondayFirst(usCalendar)
        let start = GroupingPeriod.week.start(of: date(2026, 10, 25), calendar: calendar)
        XCTAssertTrue(GroupingPeriod.week.label(for: start, calendar: calendar).hasPrefix("Week of Oct 19"))
    }

    func testMonthAndYearLabelsUsePassedCalendar() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.locale = Locale(identifier: "en_US")
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        // 2026-12-31 23:30 in New York is 2027-01-01 13:30 in Tokyo.
        let date = TestSupport.date(year: 2026, month: 12, day: 31, hour: 23, minute: 30, calendar: usCalendar)
        XCTAssertEqual(GroupingPeriod.month.label(for: date, calendar: usCalendar), "December 2026")
        XCTAssertEqual(GroupingPeriod.month.label(for: date, calendar: tokyo), "January 2027")
        XCTAssertEqual(GroupingPeriod.year.label(for: date, calendar: usCalendar), "2026")
        XCTAssertEqual(GroupingPeriod.year.label(for: date, calendar: tokyo), "2027")
    }

    func testISOWeekNumbering() {
        let calendar = Calendar.mondayFirst(usCalendar)
        // Jan 1, 2027 is a Friday, so ISO week 1 of 2027 starts Mon Jan 4; Jan 1 is in week 53 of 2026.
        XCTAssertEqual(calendar.component(.weekOfYear, from: date(2027, 1, 1)), 53)
        XCTAssertEqual(calendar.component(.weekOfYear, from: date(2027, 1, 4)), 1)
    }

    func testDefaultUsesAppCalendar() {
        // Without an explicit calendar, grouping uses Calendar.app (Monday-first) on any device.
        let sunday = TestSupport.date(year: 2026, month: 10, day: 25, hour: 12, calendar: .app)
        let start = GroupingPeriod.week.start(of: sunday)
        XCTAssertEqual(Calendar.app.component(.weekday, from: start), 2)
    }
}

final class WattsRPMTests: XCTestCase {
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()
    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        TestSupport.date(year: year, month: month, day: day, hour: hour, calendar: calendar)
    }

    func ride(_ date: Date, minutes: Double, watts: Int, rpm: Int) -> Workout {
        TestSupport.ride(date: date, durationMinutes: minutes, avgRPM: rpm, avgWatts: watts)
    }
    lazy var now = date(2026, 10, 22)

    func testTimeWeightedAverages() {
        // 60 min @ 100 W / 80 rpm and 30 min @ 70 W / 74 rpm → (6000+2100)/90 = 90 W, (4800+2220)/90 = 78 rpm.
        let totals = Totals([ride(now, minutes: 60, watts: 100, rpm: 80), ride(now, minutes: 30, watts: 70, rpm: 74)])
        XCTAssertEqual(totals.averageWatts ?? -1, 90, accuracy: 0.001)
        XCTAssertEqual(totals.averageRPM ?? -1, 78, accuracy: 0.001)
    }

    func testRidesWithoutValueAreIgnored() {
        // A ride with 0 W / 0 rpm (not recorded) doesn't drag the average down.
        let totals = Totals([ride(now, minutes: 45, watts: 88, rpm: 75), ride(now, minutes: 45, watts: 0, rpm: 0)])
        XCTAssertEqual(totals.averageWatts ?? -1, 88, accuracy: 0.001)
        XCTAssertEqual(totals.averageRPM ?? -1, 75, accuracy: 0.001)
    }

    func testSimpleMeanWhenNoDurations() {
        let totals = Totals([ride(now, minutes: 0, watts: 80, rpm: 70), ride(now, minutes: 0, watts: 90, rpm: 80)])
        XCTAssertEqual(totals.averageWatts ?? -1, 85, accuracy: 0.001)
        XCTAssertEqual(totals.averageRPM ?? -1, 75, accuracy: 0.001)
    }

    func testMissingValuesShowDash() {
        let totals = Totals([ride(now, minutes: 30, watts: 0, rpm: 0)])
        XCTAssertNil(totals.averageWatts)
        XCTAssertNil(Totals([]).averageRPM)
        let summary = PeriodSummary.compute([], period: .week, now: now, calendar: calendar)
        XCTAssertEqual(summary.valueText(.watts).value, "—")
        XCTAssertEqual(summary.valueText(.rpm).value, "—")
        XCTAssertEqual(summary.deltaText(.watts), "—")
        XCTAssertNil(summary.wattsDelta)
        XCTAssertEqual(summary.delta(.watts), 0)
    }

    func testDeltasVsPriorWindow() {
        let rides = [
            ride(date(2026, 10, 20), minutes: 48, watts: 88, rpm: 75),   // last 7 days
            ride(date(2026, 10, 18), minutes: 46, watts: 97, rpm: 74),   // last 7 days
            ride(date(2026, 10, 12), minutes: 42, watts: 79, rpm: 79),   // prior 7 days
        ]
        let summary = PeriodSummary.compute(rides, period: .week, now: now, calendar: calendar)
        // Current: (88*48 + 97*46)/94 = 92.4 → 92 W; (75*48 + 74*46)/94 = 74.5 → 75 rpm (rounded)
        XCTAssertEqual(summary.valueText(.watts).value, "92 W")
        XCTAssertEqual(summary.valueText(.watts).label, "Watts")
        XCTAssertEqual(summary.valueText(.rpm).label, "RPM")
        XCTAssertEqual(summary.wattsDelta, 92 - 79)
        XCTAssertEqual(summary.deltaText(.watts), "▲ 13 W")
        let rpm = Int(summary.current.averageRPM!.rounded())
        XCTAssertEqual(summary.rpmDelta, rpm - 79)
        XCTAssertEqual(summary.deltaText(.rpm), "▼ \(79 - rpm) rpm")
    }

    func testNoPriorDataGivesDash() {
        let summary = PeriodSummary.compute([ride(date(2026, 10, 20), minutes: 48, watts: 88, rpm: 75)],
                                      period: .week, now: now, calendar: calendar)
        XCTAssertEqual(summary.valueText(.watts).value, "88 W")
        XCTAssertEqual(summary.valueText(.rpm).value, "75")
        XCTAssertEqual(summary.deltaText(.watts), "—")
        XCTAssertEqual(summary.deltaText(.rpm), "—")
    }

    func testMetricOrder() {
        XCTAssertEqual(PeriodSummary.Metric.allCases, [.rides, .time, .watts, .rpm, .elevation, .calories])
    }

    func testStatDeltaTrend() {
        XCTAssertEqual(StatDelta(text: "", value: 5, previousValue: 10).trend, .up)
        XCTAssertEqual(StatDelta(text: "", value: 0, previousValue: 10).trend, .unchanged)
        // 7 of 10 is still 70% of the previous value: a small dip.
        XCTAssertEqual(StatDelta(text: "", value: -3, previousValue: 10).trend, .smallDip)
        XCTAssertEqual(StatDelta(text: "", value: -3.5, previousValue: 10).trend, .bigDrop)
        // Without a previous value, any decline is a big drop.
        XCTAssertEqual(StatDelta(text: "", value: -1).trend, .bigDrop)
    }
}
