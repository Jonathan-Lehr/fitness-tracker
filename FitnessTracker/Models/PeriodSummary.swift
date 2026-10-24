import Foundation

/// Totals for the current week/month/year, the previous one, and per-bucket miles for a mini chart.
struct PeriodSummary {
    struct Bucket: Identifiable, Equatable {
        let start: Date
        let miles: Double
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

    enum Metric: CaseIterable { case rides, time, calories, elevation }

    /// Signed change vs the previous period, for coloring (>0 up, <0 down, 0 same).
    func delta(_ m: Metric) -> Double {
        switch m {
        case .rides: Double(ridesDelta)
        case .time: minutesDelta.rounded()
        case .calories: Double(caloriesDelta)
        case .elevation: Double(feetDelta)
        }
    }

    /// Compact delta text, e.g. "▲ 2", "▼ 15m", "▲ 120 cal", "▲ 340 ft", "– 0".
    func deltaText(_ m: Metric) -> String {
        let d = delta(m)
        let arrow = d > 0 ? "▲" : (d < 0 ? "▼" : "–")
        let mag = abs(d)
        let value: String
        switch m {
        case .rides: value = "\(Int(mag))"
        case .time: value = mag.minutesText
        case .calories: value = "\(Int(mag)) cal"
        case .elevation: value = "\(Int(mag)) ft"
        }
        return "\(arrow) \(value)"
    }

    /// Bucket size for the mini chart: days for week and month, months for year.
    static func bucketComponent(for period: GroupingPeriod) -> Calendar.Component {
        period == .year ? .month : .day
    }

    static func compute(_ workouts: [Workout], period: GroupingPeriod,
                        now: Date = .now, calendar: Calendar = .current) -> PeriodSummary {
        let interval = calendar.dateInterval(of: period.component, for: now)
            ?? DateInterval(start: now, duration: 0)
        let prevStart = calendar.date(byAdding: period.component, value: -1, to: interval.start) ?? interval.start
        let previousInterval = DateInterval(start: prevStart, end: interval.start)

        // Half-open [start, end) so a ride at exactly midnight belongs to one period only.
        func inside(_ w: Workout, _ i: DateInterval) -> Bool { w.date >= i.start && w.date < i.end }
        let current = workouts.filter { inside($0, interval) }
        let previous = workouts.filter { inside($0, previousInterval) }

        let component = bucketComponent(for: period)
        var buckets: [Bucket] = []
        var cursor = interval.start
        while cursor < interval.end {
            let next = calendar.date(byAdding: component, value: 1, to: cursor) ?? interval.end
            let slot = DateInterval(start: cursor, end: next)
            let miles = current.filter { inside($0, slot) }.reduce(0) { $0 + $1.distanceMiles }
            buckets.append(Bucket(start: cursor, miles: miles))
            cursor = next
        }

        return PeriodSummary(period: period, interval: interval,
                             current: Totals(current), previous: Totals(previous), buckets: buckets)
    }

    var title: String {
        switch period {
        case .week: "This Week"
        case .month: "This Month"
        case .year: "This Year"
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

    /// e.g. "+4.2 mi vs last week", "+12 mi"… once >= 100: "+120 mi vs last month"
    var deltaText: String {
        let sign = milesDelta > 0 ? "+" : (milesDelta < 0 ? "−" : "±")
        return "\(sign)\(Self.milesNumber(abs(milesDelta))) mi vs last \(period.rawValue.lowercased())"
    }
}
