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

    /// X (date) range for the chart: from the start of the first displayed period to the end of the
    /// last one, using the local calendar (so months and DST-affected weeks keep their real lengths).
    ///
    /// Marks are plotted with `unit:` binning, so each point sits in the middle of its period and the
    /// range covers exactly the displayed periods, with no automatic "nice" rounding adding blank space.
    /// Built from every displayed period, not just those with watts, so missing-watts periods leave a
    /// real gap and the axis lines up with the other Trends charts' date range.
    static func dateDomain(periodStarts: [Date], period: GroupingPeriod, calendar: Calendar = .app) -> ClosedRange<Date>? {
        guard let first = periodStarts.min(), let last = periodStarts.max() else { return nil }
        let end = calendar.date(byAdding: period.component, value: 1, to: last) ?? last
        return first...max(end, first)
    }
}
