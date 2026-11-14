import Foundation

extension DateInterval {
    /// Whether `date` falls in the half-open interval [start, end).
    /// Foundation's `contains` includes the end, which would put a workout at
    /// exactly an interval's end into two adjacent periods.
    func halfOpenContains(_ date: Date) -> Bool {
        date >= start && date < end
    }
}
