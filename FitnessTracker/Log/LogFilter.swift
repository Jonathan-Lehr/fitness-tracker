import Foundation

struct LogFilter: Equatable {
    var useDateRange = false
    var startDate = Calendar.app.date(byAdding: .month, value: -3, to: .now) ?? .now
    var endDate = Date.now
    var programTitle: String? = nil
    var type: WorkoutType? = nil
    var minWatts = 0

    var isActive: Bool { useDateRange || programTitle != nil || type != nil || minWatts > 0 }

    func matches(_ workout: Workout) -> Bool {
        if useDateRange {
            let calendar = Calendar.app
            let rangeStart = calendar.startOfDay(for: startDate)
            let rangeEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
            if !DateInterval(start: rangeStart, end: rangeEnd).halfOpenContains(workout.date) { return false }
        }
        if let programTitle, workout.title != programTitle { return false }
        if let type, workout.type != type { return false }
        if workout.avgWatts < minWatts { return false }
        return true
    }
}
