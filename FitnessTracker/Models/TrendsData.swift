import Foundation

enum TrendsData {}

extension TrendsData {
    /// Periods that have fully ended before `now` (the in-progress period is excluded).
    static func completedStarts(_ starts: [Date], period: GroupingPeriod, now: Date, calendar: Calendar = .app) -> [Date] {
        let currentStart = period.start(of: now, calendar: calendar)
        return starts.filter { $0 < currentStart }
    }
}
