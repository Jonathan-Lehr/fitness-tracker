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

    /// X (date) range for the chart: from the start of the first plotted period (one with watts) to the
    /// end of the last plotted period, using the local calendar (real month lengths, DST-aware weeks).
    ///
    /// Marks use `unit:` binning, so each point sits mid-period. That leaves only half a period of edge
    /// padding at each end (so points are not clipped), and no empty leading or trailing periods.
    /// Periods without watts between plotted points keep their calendar position as a gap; no values
    /// are invented.
    static func dateDomain(periodStarts: [Date], period: GroupingPeriod, calendar: Calendar = .app) -> ClosedRange<Date>? {
        guard let first = periodStarts.min(), let last = periodStarts.max() else { return nil }
        let end = calendar.date(byAdding: period.component, value: 1, to: last) ?? last
        return first...max(end, first)
    }
}
