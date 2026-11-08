import Foundation

/// Y-axis range for the Trends "Average Watts" line chart, fitted to the plotted data.
///
/// The chart is a line chart, so a non-zero baseline is honest and makes changes readable.
/// The range is the data's min/max plus padding (10% of the span, at least 5 W on each
/// side, so single or constant values sit mid-chart), rounded out to multiples of 5 W and
/// never below 0.
enum WattsAxis {
    static let minimumPadding = 5.0
    static let step = 5.0

    /// Returns nil when there are no valid (finite, > 0) values; the chart then uses its default scale.
    static func domain(for values: [Double]) -> ClosedRange<Double>? {
        let valid = values.filter { $0.isFinite && $0 > 0 }
        guard let lo = valid.min(), let hi = valid.max() else { return nil }
        let pad = max((hi - lo) * 0.1, minimumPadding)
        let lower = max(0, ((lo - pad) / step).rounded(.down) * step)
        let upper = ((hi + pad) / step).rounded(.up) * step
        return lower...upper
    }

    /// X (date) range for the chart: exactly the first to the last plotted period start (periods with watts).
    ///
    /// Marks are plotted at each period's start date (no `unit:` binning), so the first and last points sit
    /// on the domain ends. The view adds only a small pixel inset (`.plotDimension(padding:)`) so the dots
    /// aren't clipped, with no temporal margin. A single point is centered in a one-period-wide range.
    /// Returns nil when there are no points.
    static func dateDomain(periodStarts: [Date], period: GroupingPeriod, calendar: Calendar = .app) -> ClosedRange<Date>? {
        guard let first = periodStarts.min(), let last = periodStarts.max() else { return nil }
        if first < last { return first...last }
        let next = calendar.date(byAdding: period.component, value: 1, to: first) ?? first.addingTimeInterval(7 * 86_400)
        let half = next.timeIntervalSince(first) / 2
        return first.addingTimeInterval(-half)...first.addingTimeInterval(half)
    }

    struct Point: Equatable {
        let start: Date
        let watts: Double
    }

    /// A run of points to draw as one line: solid between adjacent periods, or a dashed bridge
    /// between two measured points separated by one or more periods without watts.
    struct Segment: Equatable {
        let isGap: Bool
        let points: [Point]
    }

    /// Splits measured points into solid runs of consecutive periods and dashed two-point bridges across
    /// missing periods. Only measured points are used: nothing is interpolated, zero-filled or extended past the ends.
    static func segments(_ points: [Point], period: GroupingPeriod, calendar: Calendar = .app) -> [Segment] {
        let sorted = points.sorted { $0.start < $1.start }
        guard var run = sorted.first.map({ [$0] }) else { return [] }
        var result: [Segment] = []
        for p in sorted.dropFirst() {
            let prev = run[run.count - 1]
            let next = calendar.date(byAdding: period.component, value: 1, to: prev.start) ?? prev.start
            if p.start <= next {
                run.append(p)
            } else {
                result.append(Segment(isGap: false, points: run))
                result.append(Segment(isGap: true, points: [prev, p]))
                run = [p]
            }
        }
        result.append(Segment(isGap: false, points: run))
        return result
    }
}
