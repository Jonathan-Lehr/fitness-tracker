import Foundation

/// How the Log shows workouts: expanded photo cards or compact text rows. Persisted so the Log
/// reopens in the last chosen style.
enum RowStyle: String, CaseIterable, Identifiable {
    // Raw values are the stored `logLayout` values from when this was LogLayout (.grid / .list).
    // Keep them so the saved choice survives.
    case expanded = "grid"
    case compact = "list"

    var id: String { rawValue }
    var label: String { self == .compact ? "Compact" : "Expanded" }
    var systemImage: String { self == .compact ? "rectangle.compress.vertical" : "rectangle.expand.vertical" }
}

/// One calendar day of workouts in the expanded row style.
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
