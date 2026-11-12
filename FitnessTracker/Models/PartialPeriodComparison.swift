import Foundation

/// The in-progress current period ("so far") compared with the same elapsed portion of the
/// previous calendar period.
///
/// Alignment rules (local calendar, so DST and month lengths follow wall-clock dates, not fixed seconds):
/// - Week (Monday-first): same weekday and time of day last week (Mon 00:00 → Wed 15:00 vs Mon 00:00 → Wed 15:00).
/// - Month: same day of month and time (Mar 1 → Mar 20 15:00 vs Feb 1 → Feb 20 15:00). If the previous
///   month is shorter, the window is clipped to that month's end (Mar 31 vs all of February).
/// - Year: same month, day and time (Jan 1 → Mar 15 vs Jan 1 → Mar 15 of last year); Feb 29 clips to the end of Feb 28.
/// Both windows are half-open: [start, end). Nothing is extrapolated to a full period.
struct PartialPeriodComparison {
    let period: GroupingPeriod
    let current: DateInterval
    let previous: DateInterval
    let currentTotals: Totals
    let previousTotals: Totals

    init(workouts: [Workout], period: GroupingPeriod, now: Date, calendar: Calendar = .app) {
        let windows = Self.windows(period: period, now: now, calendar: calendar)
        self.period = period
        current = windows.current
        previous = windows.previous
        currentTotals = Totals(workouts.filter { windows.current.halfOpenContains($0.date) })
        previousTotals = Totals(workouts.filter { windows.previous.halfOpenContains($0.date) })
    }

    static func windows(period: GroupingPeriod, now: Date, calendar: Calendar = .app)
        -> (current: DateInterval, previous: DateInterval) {
        let currentStart = period.start(of: now, calendar: calendar)
        let previousStart = calendar.date(byAdding: period.component, value: -1, to: currentStart) ?? currentStart
        // Wall-clock alignment: find the corresponding calendar day in the previous period, then apply
        // today's time of day. Day/time math goes through the calendar, so DST days of 23 or 25 hours are handled.
        let today = calendar.startOfDay(for: now)
        let correspondingDay: Date?
        switch period {
        case .week, .month:
            let dayOffset = calendar.dateComponents([.day], from: calendar.startOfDay(for: currentStart), to: today).day ?? 0
            correspondingDay = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: previousStart))
        case .year:
            let md = calendar.dateComponents([.month, .day], from: now)
            var c = calendar.dateComponents([.era, .year], from: previousStart)
            c.month = md.month
            c.day = 1
            correspondingDay = calendar.date(from: c).flatMap { calendar.date(byAdding: .day, value: (md.day ?? 1) - 1, to: $0) }
                .map { calendar.startOfDay(for: $0) }
        }
        let previousEnd: Date
        if let day = correspondingDay, day < currentStart,
           // A shorter previous month (or Feb 29 in a non-leap year) spills past its month; clip below.
           period != .year || calendar.component(.month, from: day) == calendar.component(.month, from: now) {
            let t = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: now)
            let end = calendar.date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: t.second ?? 0, of: day)
                .map { $0.addingTimeInterval(Double(t.nanosecond ?? 0) / 1e9) } ?? day
            previousEnd = min(max(end, previousStart), currentStart)
        } else if let day = correspondingDay, period == .year {
            previousEnd = calendar.startOfDay(for: day) // e.g. Feb 29 -> end of Feb 28 (start of Mar 1)
        } else {
            previousEnd = currentStart // whole previous period (shorter month)
        }
        return (DateInterval(start: currentStart, end: max(now, currentStart)),
                DateInterval(start: previousStart, end: previousEnd))
    }
}
