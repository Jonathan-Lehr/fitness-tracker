import Foundation

extension Calendar {
    /// The app's calendar for calendar-week logic: weeks start on Monday with ISO 8601 week
    /// numbering (minimumDaysInFirstWeek = 4), regardless of the device's region settings.
    /// Keeps the device's calendar identifier, time zone and locale otherwise.
    static func mondayFirst(_ base: Calendar = .current) -> Calendar {
        var c = base
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4
        return c
    }

    /// Shared app calendar (Monday-first weeks).
    static var app: Calendar { mondayFirst() }
}

extension DateInterval {
    /// Whether `date` falls in the half-open interval [start, end).
    /// Foundation's `contains` includes the end, which would put a ride at
    /// exactly an interval's end into two adjacent periods.
    func halfOpenContains(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

