import Foundation

enum GroupingPeriod: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var id: String { rawValue }

    var component: Calendar.Component {
        switch self {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }

    /// Start of the calendar week (Monday), month or year containing `date`.
    func start(of date: Date, calendar: Calendar = .app) -> Date {
        calendar.dateInterval(of: component, for: date)?.start ?? date
    }

    func label(for start: Date, calendar: Calendar = .app) -> String {
        let style = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone)
        switch self {
        case .week: return "Week of " + start.formatted(style.month(.abbreviated).day().year())
        case .month: return start.formatted(style.month(.wide).year())
        case .year: return start.formatted(style.year())
        }
    }
}
