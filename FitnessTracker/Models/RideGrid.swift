import Foundation

/// Log presentation mode; persisted so the Log reopens in the last chosen mode.
enum LogLayout: String, CaseIterable, Identifiable {
    case grid
    case list
    var id: String { rawValue }
    var label: String { self == .list ? "List" : "Grid" }
    var systemImage: String { self == .list ? "list.bullet" : "square.grid.2x2" }
}

/// One calendar day of rides in the grid view.
struct DayGroup<Item> {
    let day: Date
    let items: [Item]

    /// Groups items by calendar day: days newest first, items within a day newest first.
    static func group(_ items: [Item], date: (Item) -> Date, calendar: Calendar = .app) -> [DayGroup<Item>] {
        let byDay = Dictionary(grouping: items) { calendar.startOfDay(for: date($0)) }
        return byDay.keys.sorted(by: >).map { day in
            DayGroup(day: day, items: (byDay[day] ?? []).sorted { date($0) > date($1) })
        }
    }
}
