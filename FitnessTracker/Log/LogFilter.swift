import Foundation

struct LogFilter: Equatable {
    var useDateRange = false
    var startDate = Calendar.app.date(byAdding: .month, value: -3, to: .now) ?? .now
    var endDate = Date.now
    var programTitle: String? = nil
    var type: WorkoutType? = nil
    var minWatts = 0

    var isActive: Bool { useDateRange || programTitle != nil || type != nil || minWatts > 0 }

    func matches(_ w: Workout) -> Bool {
        if useDateRange {
            let cal = Calendar.app
            let lo = cal.startOfDay(for: startDate)
            let hi = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: endDate)) ?? endDate
            if !DateInterval(start: lo, end: hi).halfOpenContains(w.date) { return false }
        }
        if let programTitle, w.title != programTitle { return false }
        if let type, w.type != type { return false }
        if w.avgWatts < minWatts { return false }
        return true
    }
}
