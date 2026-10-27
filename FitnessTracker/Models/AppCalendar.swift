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
