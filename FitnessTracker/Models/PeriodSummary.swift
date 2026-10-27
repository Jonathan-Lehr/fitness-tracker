import Foundation

/// Totals for a rolling window ending today (last 7 / 30 / 365 calendar days, inclusive of
/// today, local time zone), the equally long window before it, and per-bucket miles for the chart.
struct PeriodSummary {
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

    var milesDelta: Double { current.miles - previous.miles }
    var ridesDelta: Int { current.count - previous.count }
    var minutesDelta: Double { current.minutes - previous.minutes }
    var caloriesDelta: Int { current.calories - previous.calories }
    var feetDelta: Int { current.feet - previous.feet }

    /// Whole-number change in average watts / RPM; nil if either window has no data.
    var wattsDelta: Int? {
        guard let a = current.averageWatts, let b = previous.averageWatts else { return nil }
        return Int(a.rounded()) - Int(b.rounded())
    }
    var rpmDelta: Int? {
        guard let a = current.averageRPM, let b = previous.averageRPM else { return nil }
        return Int(a.rounded()) - Int(b.rounded())
    }

    enum Metric: CaseIterable { case rides, time, calories, elevation, watts, rpm }

    /// Signed change vs the previous period, for coloring (>0 up, <0 down, 0 same/unknown).
    func delta(_ m: Metric) -> Double {
        switch m {
        case .rides: Double(ridesDelta)
        case .time: minutesDelta.rounded()
        case .calories: Double(caloriesDelta)
        case .elevation: Double(feetDelta)
        case .watts: Double(wattsDelta ?? 0)
        case .rpm: Double(rpmDelta ?? 0)
        }
    }

    /// Compact delta text, e.g. "▲ 2", "▼ 15m", "▲ 120 cal", "▲ 340 ft", "▲ 12 W", "▼ 3 rpm",
    /// "– 0"; "—" when an average can't be compared (no data in either window).
    func deltaText(_ m: Metric) -> String {
        if (m == .watts && wattsDelta == nil) || (m == .rpm && rpmDelta == nil) { return "—" }
        let d = delta(m)
        let arrow = d > 0 ? "▲" : (d < 0 ? "▼" : "–")
        let mag = abs(d)
        let value: String
        switch m {
        case .rides: value = "\(Int(mag))"
        case .time: value = mag.minutesText
        case .calories: value = "\(Int(mag)) cal"
        case .elevation: value = "\(Int(mag)) ft"
        case .watts: value = "\(Int(mag)) W"
        case .rpm: value = "\(Int(mag)) rpm"
        }
        return "\(arrow) \(value)"
    }

    /// Display value and label for a metric ("—" for averages with no data).
    func valueText(_ m: Metric) -> (value: String, label: String) {
        let t = current
        switch m {
        case .rides: return ("\(t.count)", "Rides")
        case .time: return (t.minutes.minutesText, "Time")
        case .calories: return ("\(t.calories)", "Calories")
        case .elevation: return ("\(t.feet) ft", "Elevation")
        case .watts: return (t.averageWatts.map { "\(Int($0.rounded())) W" } ?? "—", "Watts")
        case .rpm: return (t.averageRPM.map { "\(Int($0.rounded()))" } ?? "—", "RPM")
        }
    }

    /// Numeric value driving the rolling-digit animation.
    func numericValue(_ m: Metric) -> Double {
        let t = current
        switch m {
        case .rides: return Double(t.count)
        case .time: return t.minutes
        case .calories: return Double(t.calories)
        case .elevation: return Double(t.feet)
        case .watts: return (t.averageWatts ?? 0).rounded()
        case .rpm: return (t.averageRPM ?? 0).rounded()
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

    /// Chart buckets:
    /// - Week: 7 daily bars ending today, every day labeled (weekday initial).
    /// - Month: 30 daily bars ending today, labeled every 7th day counting back from today.
    /// - Year: 12 monthly bars ending with the current month; the first bar also absorbs the
    ///   few days of the 365-day window that fall before it. Labeled every 3rd month from the end.
    static func makeBuckets(period: GroupingPeriod, interval: DateInterval, calendar: Calendar,
                            miles: (DateInterval) -> Double) -> [Bucket] {
        var bounds: [Date] = []
        switch period {
        case .week, .month:
            var d = interval.start
            while d < interval.end {
                bounds.append(d)
                d = calendar.date(byAdding: .day, value: 1, to: d) ?? interval.end
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
        case .week: format = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).weekday(.narrow); every = 1
        case .month: format = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).day(); every = 7
        case .year: format = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).month(.narrow); every = 3
        }
        return bounds.enumerated().map { i, start in
            let end = i + 1 < bounds.count ? bounds[i + 1] : interval.end
            // Label from the end so today / the current month is always labeled.
            let labeled = (bounds.count - 1 - i) % every == 0
            // For the Year's first (stretched) bucket, label by the month it mostly covers.
            let labelDate = period == .year && i == 0 ? (calendar.date(byAdding: .day, value: -1, to: end) ?? start) : start
            return Bucket(start: start, end: end,
                          miles: miles(DateInterval(start: start, end: end)),
                          label: labeled ? labelDate.formatted(format) : nil)
        }
    }

    static func compute(_ workouts: [Workout], period: GroupingPeriod,
                        now: Date = .now, calendar: Calendar = .current) -> PeriodSummary {
        let n = days(for: period)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let start = calendar.date(byAdding: .day, value: -n, to: end) ?? end
        let prevStart = calendar.date(byAdding: .day, value: -n, to: start) ?? start
        let interval = DateInterval(start: start, end: end)
        let previousInterval = DateInterval(start: prevStart, end: start)

        // Half-open [start, end) so a ride at exactly midnight belongs to one window only.
        func inside(_ w: Workout, _ i: DateInterval) -> Bool { w.date >= i.start && w.date < i.end }
        let current = workouts.filter { inside($0, interval) }
        let previous = workouts.filter { inside($0, previousInterval) }

        let buckets = makeBuckets(period: period, interval: interval, calendar: calendar) { slot in
            current.filter { inside($0, slot) }.reduce(0) { $0 + $1.distanceMiles }
        }
        return PeriodSummary(period: period, interval: interval,
                             current: Totals(current), previous: Totals(previous), buckets: buckets)
    }

    var title: String { "Last \(Self.days(for: period)) Days" }

    /// Miles for display: one decimal below 100 ("9.9", "99.9"), whole number with grouping
    /// at 100 and above ("100", "1,235") so month/year totals fit the hero slot.
    static func milesNumber(_ miles: Double, locale: Locale = .current) -> String {
        if abs(miles) < 99.95 {
            return miles.formatted(.number.precision(.fractionLength(1)).rounded(rule: .toNearestOrEven).locale(locale))
        }
        return miles.formatted(.number.precision(.fractionLength(0)).rounded(rule: .toNearestOrAwayFromZero)
            .grouping(.automatic).locale(locale))
    }

    /// e.g. "+4.2 mi vs prior 7 days"; whole miles at 100+: "+120 mi vs prior 30 days"
    var deltaText: String {
        let sign = milesDelta > 0 ? "+" : (milesDelta < 0 ? "−" : "±")
        return "\(sign)\(Self.milesNumber(abs(milesDelta))) mi vs prior \(Self.days(for: period)) days"
    }
}
