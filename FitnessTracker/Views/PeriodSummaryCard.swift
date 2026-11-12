import SwiftUI
import Charts

/// A change shown under a stat, colored by direction: green up, yellow for a small dip,
/// red for a big drop, secondary when unchanged.
struct StatDelta {
    /// How a change compares with the previous value.
    enum Trend: Equatable {
        case up, unchanged, smallDip, bigDrop
    }

    /// A decline is a small dip while the new value is still at least this fraction of the previous one.
    static let smallDipThreshold = 0.7

    let text: String
    /// Signed change; drives the color and the rolling-digit animation.
    let value: Double
    /// The value being compared against. When it's unknown, every decline counts as a big drop.
    var previousValue: Double? = nil

    var trend: Trend {
        if value > 0 { return .up }
        if value == 0 { return .unchanged }
        guard let previousValue, previousValue > 0 else { return .bigDrop }
        let currentValue = previousValue + value
        return currentValue / previousValue >= Self.smallDipThreshold ? .smallDip : .bigDrop
    }

    var color: Color {
        switch trend {
        case .up: .green
        case .unchanged: .secondary
        case .smallDip: AppColor.smallDipYellow.color
        case .bigDrop: .red
        }
    }
}

/// One metric: value, label, and an optional delta. Shared by the period summary cards and the
/// workout detail card so their stat styling stays identical. The delta row appears only when
/// comparison data is available.
struct StatTile: View {
    let value: String
    let label: String
    var delta: StatDelta? = nil
    var numericValue: Double = 0
    /// Reports the value text's width (the period card uses it to size its landscape chart).
    var onValueWidthChange: ((CGFloat) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            valueText
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let delta {
                deltaText(delta)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
    }

    private var valueText: some View {
        Text(value)
            .font(.headline.weight(.semibold))
            .monospacedDigit()
            .contentTransition(transition(for: numericValue))
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                onValueWidthChange?(width)
            }
    }

    private func deltaText(_ delta: StatDelta) -> some View {
        Text(delta.text)
            .contentTransition(transition(for: delta.value))
            .font(.caption2.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(delta.color)
    }

    private func transition(for value: Double) -> ContentTransition {
        reduceMotion ? .opacity : .numericText(value: value)
    }
}

struct PeriodSummaryCard: View {
    @Binding var period: GroupingPeriod
    let summary: PeriodSummary
    var filtered: Bool = false
    /// The Log's overview card shows the Week/Month/Year picker and drives Mac window sizing;
    /// the past-period sheet shows a fixed period and does neither.
    var showsPeriodPicker: Bool = true

    static let columnSpacing: CGFloat = 16

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Rolling digits for numbers; a plain crossfade when Reduce Motion is on.
    private func numeric(_ value: Double) -> ContentTransition {
        reduceMotion ? .opacity : .numericText(value: value)
    }

    /// Measured card width; drives the layout instead of size classes (a non-Max iPhone in
    /// landscape reports a compact horizontal size class).
    @State private var cardWidth: CGFloat = 0
    /// Measured width of the last stat's value text (Calories, i.e. Metric.allCases.last);
    /// the landscape chart's trailing edge stops there.
    @State private var lastStatWidth: CGFloat = 0

    /// Wide layout: one row of six equal stat columns. The hero spans columns 1–2 and the
    /// chart runs from column 3 to the end of the last stat's content.
    static let wideColumns = PeriodSummary.Metric.allCases.count   // 6
    static let heroColumns = 2
    /// Narrow (iPhone portrait, narrow Mac window): 3 columns × 2 rows. On a 402-pt iPhone 16 Pro
    /// each column is ~99 pt, enough for the longest typical value ("123h 45m") and delta
    /// ("▲ 1,234 cal") at full size; minimumScaleFactor covers outliers.
    static let narrowColumns = 3

    private var wideColumnWidth: CGFloat {
        let n = CGFloat(Self.wideColumns)
        return max(0, (cardWidth - (n - 1) * Self.columnSpacing) / n)
    }

    private var wideHeroWidth: CGFloat {
        CGFloat(Self.heroColumns) * wideColumnWidth + CGFloat(Self.heroColumns - 1) * Self.columnSpacing
    }

    private var wideChartWidth: CGFloat {
        let col = wideColumnWidth
        let span = Self.wideColumns - Self.heroColumns            // columns 3…6
        let last = lastStatWidth > 0 ? min(lastStatWidth, col) : col
        return max(0, CGFloat(span - 1) * (col + Self.columnSpacing) + last)
    }

    #if os(iOS)
    @Environment(\.verticalSizeClass) private var vSize
    private var useWideLayout: Bool { vSize == .compact || cardWidth > 600 }
    #else
    // Six columns need room; a narrow Mac window falls back to the 3-column grid.
    private var useWideLayout: Bool { cardWidth == 0 || cardWidth >= 560 }
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Drive the period change in an animated transaction so numericText content
            // transitions (and the chart) animate; implicit .animation(value:) on a List row
            // wasn't reliably applied.
            if showsPeriodPicker {
                Picker("Period", selection: $period.animation(.default)) {
                    ForEach(GroupingPeriod.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if useWideLayout {
                // Wide (Mac, iPhone landscape): a 6-column grid. Top row: hero over columns 1–2,
                // chart from column 3 to the end of the last (Calories) stat's value; bottom row: one
                // stat per column.
                HStack(alignment: .bottom, spacing: Self.columnSpacing) {
                    hero.frame(width: wideHeroWidth, alignment: .leading)
                    chart.frame(width: wideChartWidth)
                    Spacer(minLength: 0)
                }
                statsGrid(columns: Self.wideColumns)
            } else {
                // Narrow (iPhone portrait, narrow Mac): miles + chart, then a 3-column grid (2 rows):
                // Rides | Time | Watts / RPM | Elevation | Calories.
                HStack(alignment: .bottom) {
                    hero.layoutPriority(1)
                    Spacer(minLength: 16)
                    chart.frame(minWidth: 80, maxWidth: 200)
                }
                statsGrid(columns: Self.narrowColumns)
            }
        }
        .padding(.vertical, 6)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
            cardWidth = $0
            #if os(macOS)
            if showsPeriodPicker { SummaryCardMetrics.shared.cardWidth = $0 }
            #endif
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(summary.title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                if filtered {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.caption).foregroundStyle(.secondary)
                        .help("Filters applied")
                }
            }
            if summary.kind == .calendar {
                Text(summary.dateRangeText).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(PeriodSummary.milesNumber(summary.current.miles))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(numeric(summary.current.miles))
                Text("mi").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
            }
            Text(summary.deltaText)
                .contentTransition(numeric(summary.milesDelta))
                .monospacedDigit()
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(heroDelta.color)
        }
    }

    private var heroDelta: StatDelta {
        StatDelta(text: summary.deltaText, value: summary.milesDelta, previousValue: summary.previous.miles)
    }

    /// Stats in equal flexible columns spanning the full card width, each leading-aligned.
    private func statsGrid(columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.columnSpacing, alignment: .leading),
                                 count: columns),
                  alignment: .leading, spacing: 12) {
            ForEach(PeriodSummary.Metric.allCases, id: \.self) { m in
                stat(m)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stat(_ metric: PeriodSummary.Metric) -> some View {
        let (value, label) = summary.valueText(metric)
        let isLast = metric == PeriodSummary.Metric.allCases.last
        return StatTile(
            value: value,
            label: label,
            delta: StatDelta(text: summary.deltaText(metric), value: summary.delta(metric),
                             previousValue: summary.previousValue(metric)),
            numericValue: summary.numericValue(metric),
            // The last stat's value width sets where the landscape chart ends.
            onValueWidthChange: isLast ? { lastStatWidth = $0 } : nil
        )
    }

    // The chart uses a categorical x axis (one band per bucket, keyed by index) so bars,
    // tracks, ticks and labels all share the same band centers. Date-based x values put
    // ticks/labels at bucket boundaries, which drifted half a slot from the bars.
    private func key(_ index: Int) -> String { String(index) }

    private var labeledKeys: [String] {
        summary.buckets.indices.filter { summary.buckets[$0].label != nil }.map(key)
    }

    private func label(forKey k: String) -> String {
        guard let i = Int(k), summary.buckets.indices.contains(i) else { return "" }
        return summary.buckets[i].label ?? ""
    }

    private var chart: some View {
        let top = max(summary.buckets.map(\.miles).max() ?? 0, 0.1)
        let keys = summary.buckets.indices.map(key)
        return Chart {
            ForEach(Array(summary.buckets.enumerated()), id: \.offset) { i, b in
                // Faint full-height track behind every bucket, so empty days read as empty.
                BarMark(x: .value("Bucket", key(i)), yStart: .value("Track", 0), yEnd: .value("Track", top))
                    .foregroundStyle(Color.secondary.opacity(0.1))
                    .cornerRadius(2)
                BarMark(x: .value("Bucket", key(i)), yStart: .value("Start", 0), yEnd: .value("Miles", b.miles))
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(2)
            }
            // Hairline baseline.
            RuleMark(y: .value("Baseline", 0))
                .lineStyle(StrokeStyle(lineWidth: 0.75))
                .foregroundStyle(Color.secondary.opacity(0.5))
        }
        .chartXScale(domain: keys)
        .chartYScale(domain: 0...top)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: labeledKeys) { value in
                AxisValueLabel(verticalSpacing: 3) {
                    if let k = value.as(String.self) { Text(label(forKey: k)) }
                }
            }
        }
        .frame(height: 70)
    }
}
