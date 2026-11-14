import Foundation

/// Totals for a window, the comparison window before it, and per-bucket miles for the chart.
/// Two kinds:
/// - rolling: last 7 / 30 / 365 calendar days ending today (local time zone) vs the equally long
///   window before it (the Log's overview card);
/// - calendar: one calendar week (Monday-first), month or year vs the calendar period before it
///   (the past-period summary sheet).
struct PeriodSummary {
    enum Kind: Equatable {
        case rolling
        case calendar
    }

    struct Bucket: Identifiable, Equatable {
        let start: Date
        let end: Date
        let miles: Double
        /// Axis label, or nil for unlabeled slots (keeps the Month axis readable).
        let label: String?
        var id: Date { start }
    }

    let period: GroupingPeriod
    let interval: DateInterval
    let current: Totals
    let previous: Totals
    let buckets: [Bucket]
    var kind: Kind = .rolling
    /// Calendar used to build the summary (labels and date range text use it too).
    var calendar: Calendar = .app

    var milesDelta: Double { current.miles - previous.miles }
    var workoutsDelta: Int { current.count - previous.count }
    var minutesDelta: Double { current.minutes - previous.minutes }
    var caloriesDelta: Int { current.calories - previous.calories }
    var feetDelta: Int { current.feet - previous.feet }

    /// Whole-number change in average watts / RPM; nil if either window has no data.
    var wattsDelta: Int? {
        guard let currentWatts = current.averageWatts, let previousWatts = previous.averageWatts else { return nil }
        return Int(currentWatts.rounded()) - Int(previousWatts.rounded())
    }
    var rpmDelta: Int? {
        guard let currentRPM = current.averageRPM, let previousRPM = previous.averageRPM else { return nil }
        return Int(currentRPM.rounded()) - Int(previousRPM.rounded())
    }

    /// Display order on the card (grid reads left-to-right, top-to-bottom; the last stat's
    /// width sets where the landscape chart ends).
    enum Metric: CaseIterable {
        case workouts
        case time
        case watts
        case rpm
        case elevation
        case calories

        var label: String {
            switch self {
            case .workouts: "Workouts"
            case .time: "Time"
            case .watts: "Watts"
            case .rpm: "RPM"
            case .elevation: "Elevation"
            case .calories: "Calories"
            }
        }
    }

    /// Signed change vs the previous period, for coloring (>0 up, <0 down, 0 same/unknown).
    func delta(_ metric: Metric) -> Double {
        switch metric {
        case .workouts: Double(workoutsDelta)
        case .time: minutesDelta.rounded()
        case .calories: Double(caloriesDelta)
        case .elevation: Double(feetDelta)
        case .watts: Double(wattsDelta ?? 0)
        case .rpm: Double(rpmDelta ?? 0)
        }
    }

    /// Compact delta text, e.g. "▲ 2", "▼ 15m", "▲ 120 cal", "▲ 340 ft", "▲ 12 W", "▼ 3 rpm",
    /// "– 0"; "—" when an average can't be compared (no data in either window).
    func deltaText(_ metric: Metric, locale: Locale = .current) -> String {
        if (metric == .watts && wattsDelta == nil) || (metric == .rpm && rpmDelta == nil) { return "—" }
        let change = delta(metric)
        let arrow = change > 0 ? "▲" : (change < 0 ? "▼" : "–")
        let magnitude = abs(change)
        let value: String
        switch metric {
        case .workouts: value = Int(magnitude).formattedWholeNumber(locale: locale)
        case .time: value = magnitude.formattedMinutes(locale: locale)
        case .calories: value = "\(Int(magnitude).formattedWholeNumber(locale: locale)) cal"
        case .elevation: value = "\(Int(magnitude).formattedWholeNumber(locale: locale)) ft"
        case .watts: value = "\(Int(magnitude).formattedWholeNumber(locale: locale)) W"
        case .rpm: value = "\(Int(magnitude).formattedWholeNumber(locale: locale)) rpm"
        }
        return "\(arrow) \(value)"
    }

    /// Display value and label for a metric ("—" for averages with no data).
    func valueText(_ metric: Metric, locale: Locale = .current) -> (value: String, label: String) {
        switch metric {
        case .workouts: return (current.count.formattedWholeNumber(locale: locale), metric.label)
        case .time: return (current.minutes.formattedMinutes(locale: locale), metric.label)
        case .calories: return (current.calories.formattedWholeNumber(locale: locale), metric.label)
        case .elevation: return ("\(current.feet.formattedWholeNumber(locale: locale)) ft", metric.label)
        case .watts: return (formattedAverageWatts(current.averageWatts, placeholder: "—", locale: locale), metric.label)
        case .rpm: return (current.averageRPM.map { Int($0.rounded()).formattedWholeNumber(locale: locale) } ?? "—", metric.label)
        }
    }

    /// Numeric value driving the rolling-digit animation.
    func numericValue(_ metric: Metric) -> Double {
        switch metric {
        case .workouts: return Double(current.count)
        case .time: return current.minutes
        case .calories: return Double(current.calories)
        case .elevation: return Double(current.feet)
        case .watts: return (current.averageWatts ?? 0).rounded()
        case .rpm: return (current.averageRPM ?? 0).rounded()
        }
    }

    /// The previous period's value for a metric, used to judge how big a decline is.
    /// Nil for an average with no data in the previous window.
    func previousValue(_ metric: Metric) -> Double? {
        switch metric {
        case .workouts: return Double(previous.count)
        case .time: return previous.minutes
        case .calories: return Double(previous.calories)
        case .elevation: return Double(previous.feet)
        case .watts: return previous.averageWatts
        case .rpm: return previous.averageRPM
        }
    }

    /// Length of the rolling window in calendar days.
    static func days(for period: GroupingPeriod) -> Int {
        switch period {
        case .week: 7
        case .month: 30
        case .year: 365
        }
    }

    /// Chart buckets (rolling):
    /// - Week: 7 daily bars ending today, every day labeled (weekday initial).
    /// - Month: 30 daily bars ending today, labeled every 7th day counting back from today.
    /// - Year: 12 monthly bars ending with the current month; the first bar also absorbs the
    ///   few days of the 365-day window that fall before it. Labeled every 3rd month from the end.
    ///
    /// Calendar-aligned (`calendarAligned: true`, interval is exactly one calendar period):
    /// - Week: 7 daily bars Monday…Sunday, every day labeled.
    /// - Month: one daily bar per day of the month (28–31), labeled days 1, 8, 15, 22, 29.
    /// - Year: 12 monthly bars January…December, labeled J, A, J, O.
    static func makeBuckets(period: GroupingPeriod, interval: DateInterval, calendar: Calendar,
                            calendarAligned: Bool = false,
                            miles: (DateInterval) -> Double) -> [Bucket] {
        var bounds: [Date] = []
        switch period {
        case .year where calendarAligned:
            bounds = (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: interval.start) }
                .filter { $0 < interval.end }
        case .week, .month:
            var start = interval.start
            while start < interval.end {
                bounds.append(start)
                start = calendar.date(byAdding: .day, value: 1, to: start) ?? interval.end
            }
        case .year:
            let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            let currentMonth = calendar.dateInterval(of: .month, for: lastDay)?.start ?? interval.start
            bounds = (0..<12).reversed().compactMap { calendar.date(byAdding: .month, value: -$0, to: currentMonth) }
            bounds[0] = min(bounds[0], interval.start)
        }
        let format: Date.FormatStyle
        let every: Int
        switch period {
        case .week:
            format = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).weekday(.narrow)
            every = 1
        case .month:
            format = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).day()
            every = 7
        case .year:
            format = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).month(.narrow)
            every = 3
        }
        return bounds.enumerated().map { i, start in
            let end = i + 1 < bounds.count ? bounds[i + 1] : interval.end
            // Rolling: label from the end so today / the current month is always labeled.
            // Calendar-aligned: label from the start (1st of the month, January).
            let labeled = (calendarAligned ? i : bounds.count - 1 - i) % every == 0
            // For the rolling Year's first (stretched) bucket, label by the month it mostly covers.
            let labelDate = period == .year && i == 0 && !calendarAligned
                ? (calendar.date(byAdding: .day, value: -1, to: end) ?? start) : start
            return Bucket(start: start, end: end,
                          miles: miles(DateInterval(start: start, end: end)),
                          label: labeled ? labelDate.formatted(format) : nil)
        }
    }

    static func compute(_ workouts: [Workout], period: GroupingPeriod,
                        now: Date = .now, calendar: Calendar = .current) -> PeriodSummary {
        let dayCount = days(for: period)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let start = calendar.date(byAdding: .day, value: -dayCount, to: end) ?? end
        let prevStart = calendar.date(byAdding: .day, value: -dayCount, to: start) ?? start
        let interval = DateInterval(start: start, end: end)
        let previousInterval = DateInterval(start: prevStart, end: start)

        // Half-open [start, end) so a workout at exactly midnight belongs to one window only.
        func inside(_ workout: Workout, _ interval: DateInterval) -> Bool { interval.halfOpenContains(workout.date) }
        let current = workouts.filter { inside($0, interval) }
        let previous = workouts.filter { inside($0, previousInterval) }

        let buckets = makeBuckets(period: period, interval: interval, calendar: calendar) { slot in
            current.filter { inside($0, slot) }.reduce(0) { $0 + $1.distanceMiles }
        }
        return PeriodSummary(period: period, interval: interval,
                             current: Totals(current), previous: Totals(previous), buckets: buckets,
                             kind: .rolling, calendar: calendar)
    }

    /// Summary of the calendar week (Monday-first with `.app`), month or year containing `date`,
    /// compared with the calendar period immediately before it. Read-only over `workouts`.
    static func computeCalendar(_ workouts: [Workout], period: GroupingPeriod, containing date: Date,
                                calendar: Calendar = .app) -> PeriodSummary {
        let interval = calendarInterval(period, containing: date, calendar: calendar)
        let beforeStart = calendar.date(byAdding: .second, value: -1, to: interval.start) ?? interval.start
        let previousInterval = calendar.dateInterval(of: period.component, for: beforeStart)
            ?? DateInterval(start: interval.start, duration: 0)

        func inside(_ workout: Workout, _ interval: DateInterval) -> Bool { interval.halfOpenContains(workout.date) }
        let current = workouts.filter { inside($0, interval) }
        let previous = workouts.filter { inside($0, previousInterval) }
        let buckets = makeBuckets(period: period, interval: interval, calendar: calendar, calendarAligned: true) { slot in
            current.filter { inside($0, slot) }.reduce(0) { $0 + $1.distanceMiles }
        }
        return PeriodSummary(period: period, interval: interval,
                             current: Totals(current), previous: Totals(previous), buckets: buckets,
                             kind: .calendar, calendar: calendar)
    }

    /// The calendar week (Monday-first with `.app`), month or year containing `date`, local time.
    static func calendarInterval(_ period: GroupingPeriod, containing date: Date,
                                 calendar: Calendar = .app) -> DateInterval {
        calendar.dateInterval(of: period.component, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 0)
    }

    /// Workouts in the calendar period containing `date` (half-open, same range as
    /// `computeCalendar`'s totals), newest first like the Log.
    static func calendarWorkouts(_ workouts: [Workout], period: GroupingPeriod, containing date: Date,
                                 calendar: Calendar = .app) -> [Workout] {
        let interval = calendarInterval(period, containing: date, calendar: calendar)
        return workouts.filter { interval.halfOpenContains($0.date) }.sorted { $0.date > $1.date }
    }

    var title: String {
        switch kind {
        case .rolling: "Last \(Self.days(for: period)) Days"
        case .calendar: period.label(for: interval.start, calendar: calendar)
        }
    }

    /// Inclusive date range, e.g. "Nov 2 – Nov 8, 2026", "Dec 28, 2026 – Jan 3, 2027".
    var dateRangeText: String {
        let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
        let base = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone)
        let monthDay = base.month(.abbreviated).day()
        let monthDayYear = monthDay.year()
        let sameYear = calendar.component(.year, from: interval.start) == calendar.component(.year, from: lastDay)
        return "\(interval.start.formatted(sameYear ? monthDay : monthDayYear)) – \(lastDay.formatted(monthDayYear))"
    }

    /// What the deltas compare against, e.g. "prior 7 days", "prior week".
    var comparisonText: String {
        switch kind {
        case .rolling: "prior \(Self.days(for: period)) days"
        case .calendar: "prior \(period.rawValue.lowercased())"
        }
    }

    /// Miles for display: one decimal below 100 ("9.9", "99.9"), whole number with grouping
    /// at 100 and above ("100", "1,235") so month/year totals fit the hero slot.
    static func milesNumber(_ miles: Double, locale: Locale = .current) -> String {
        if abs(miles) < 99.95 {
            return miles.formatted(.number.precision(.fractionLength(1)).rounded(rule: .toNearestOrEven).locale(locale))
        }
        return miles.formatted(.number.precision(.fractionLength(0)).rounded(rule: .toNearestOrAwayFromZero)
            .grouping(.automatic).locale(locale))
    }

    /// e.g. "+4.2 mi vs prior 7 days"; whole miles at 100+: "+120 mi vs prior 30 days";
    /// calendar summaries: "+4.2 mi vs prior week"
    var deltaText: String {
        let sign = milesDelta > 0 ? "+" : (milesDelta < 0 ? "−" : "±")
        return "\(sign)\(Self.milesNumber(abs(milesDelta))) mi vs \(comparisonText)"
    }
}
