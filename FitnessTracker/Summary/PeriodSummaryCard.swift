import SwiftUI
import SwiftData
import Charts

struct PeriodSummaryCard: View {
    @Binding var period: GroupingPeriod
    let summary: PeriodSummary
    var filtered: Bool = false
    /// The Log's overview card shows the Week/Month/Year picker and drives Mac window sizing;
    /// the past-period sheet shows a fixed period and does neither.
    var showsPeriodPicker: Bool = true

    static let columnSpacing: CGFloat = 16

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
        let columnCount = CGFloat(Self.wideColumns)
        return max(0, (cardWidth - (columnCount - 1) * Self.columnSpacing) / columnCount)
    }

    private var wideHeroWidth: CGFloat {
        CGFloat(Self.heroColumns) * wideColumnWidth + CGFloat(Self.heroColumns - 1) * Self.columnSpacing
    }

    private var wideChartWidth: CGFloat {
        let columnWidth = wideColumnWidth
        let span = Self.wideColumns - Self.heroColumns            // columns 3…6
        let lastColumnWidth = lastStatWidth > 0 ? min(lastStatWidth, columnWidth) : columnWidth
        return max(0, CGFloat(span - 1) * (columnWidth + Self.columnSpacing) + lastColumnWidth)
    }

    #if os(iOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var useWideLayout: Bool { verticalSizeClass == .compact || cardWidth > 600 }
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
                    PeriodSummaryHero(summary: summary, filtered: filtered)
                        .frame(width: wideHeroWidth, alignment: .leading)
                    PeriodSummaryMileageChart(summary: summary)
                        .frame(width: wideChartWidth)
                    Spacer(minLength: 0)
                }
                statsGrid(columns: Self.wideColumns)
            } else {
                // Narrow (iPhone portrait, narrow Mac): miles + chart, then a 3-column grid (2 rows):
                // Rides | Time | Watts / RPM | Elevation | Calories.
                HStack(alignment: .bottom) {
                    PeriodSummaryHero(summary: summary, filtered: filtered)
                        .layoutPriority(1)
                    Spacer(minLength: 16)
                    PeriodSummaryMileageChart(summary: summary)
                        .frame(minWidth: 80, maxWidth: 200)
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

    /// Stats in equal flexible columns spanning the full card width, each leading-aligned.
    private func statsGrid(columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.columnSpacing, alignment: .leading),
                                 count: columns),
                  alignment: .leading, spacing: 12) {
            ForEach(PeriodSummary.Metric.allCases, id: \.self) { metric in
                stat(metric)
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
}

/// Fonts and worst-case strings shared with Mac window sizing so the measured
/// minimum width can't drift from the card.
extension PeriodSummaryCard {
    enum Typography {
        /// Text styles the card uses, so SwiftUI fonts and the AppKit fonts
        /// used for measurement stay in lockstep.
        enum TextStyle {
            case title3
            case headline
            case subheadline
            case caption
            case caption2

            var font: Font {
                switch self {
                case .title3: .title3
                case .headline: .headline
                case .subheadline: .subheadline
                case .caption: .caption
                case .caption2: .caption2
                }
            }
        }

        static let titleStyle: TextStyle = .subheadline
        static let titleWeight: Font.Weight = .semibold
        static var titleFont: Font { titleStyle.font.weight(titleWeight) }

        static let filterIconStyle: TextStyle = .caption
        static var filterIconFont: Font { filterIconStyle.font }

        static let milesSize: CGFloat = 48
        static let milesWeight: Font.Weight = .bold
        static let milesDesign: Font.Design = .rounded
        static var milesFont: Font { .system(size: milesSize, weight: milesWeight, design: milesDesign) }

        static let milesUnitStyle: TextStyle = .title3
        static let milesUnitWeight: Font.Weight = .semibold
        static var milesUnitFont: Font { milesUnitStyle.font.weight(milesUnitWeight) }
        static let milesUnit = "mi"

        static let heroDeltaStyle: TextStyle = .caption
        static let heroDeltaWeight: Font.Weight = .medium
        static var heroDeltaFont: Font { heroDeltaStyle.font.weight(heroDeltaWeight) }

        static let statValueStyle: TextStyle = .headline
        static let statValueWeight: Font.Weight = .semibold
        static var statValueFont: Font { statValueStyle.font.weight(statValueWeight) }

        static let statLabelStyle: TextStyle = .caption
        static var statLabelFont: Font { statLabelStyle.font }

        static let statDeltaStyle: TextStyle = .caption2
        static let statDeltaWeight: Font.Weight = .medium
        static var statDeltaFont: Font { statDeltaStyle.font.weight(statDeltaWeight) }

        /// Longest rolling title (the year window).
        static let widestTitle = "Last \(PeriodSummary.days(for: .year)) Days"
        /// Longest realistic hero mileage figure over a 365-day window.
        static let widestMiles = "8888"
        /// Longest realistic hero delta for a 365-day window.
        static let widestHeroDelta = "−888 mi vs prior \(PeriodSummary.days(for: .year)) days"
    }
}

/// Title, mileage, and delta for the period summary card.
private struct PeriodSummaryHero: View {
    let summary: PeriodSummary
    var filtered: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var heroDelta: StatDelta {
        StatDelta(text: summary.deltaText, value: summary.milesDelta, previousValue: summary.previous.miles)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(summary.title).font(PeriodSummaryCard.Typography.titleFont).foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                if filtered {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(PeriodSummaryCard.Typography.filterIconFont).foregroundStyle(.secondary)
                        .help("Filters applied")
                }
            }
            if summary.kind == .calendar {
                Text(summary.dateRangeText).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(PeriodSummary.milesNumber(summary.current.miles))
                    .font(PeriodSummaryCard.Typography.milesFont)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(numericContentTransition(value: summary.current.miles, reduceMotion: reduceMotion))
                Text(PeriodSummaryCard.Typography.milesUnit)
                    .font(PeriodSummaryCard.Typography.milesUnitFont)
                    .foregroundStyle(.secondary)
            }
            Text(summary.deltaText)
                .contentTransition(numericContentTransition(value: summary.milesDelta, reduceMotion: reduceMotion))
                .monospacedDigit()
                .font(PeriodSummaryCard.Typography.heroDeltaFont)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(heroDelta.color)
        }
    }
}

/// Daily (or weekly/monthly) mileage bars for the period summary card.
///
/// The chart uses a categorical x axis (one band per bucket, keyed by index) so bars,
/// tracks, ticks and labels all share the same band centers. Date-based x values put
/// ticks/labels at bucket boundaries, which drifted half a slot from the bars.
private struct PeriodSummaryMileageChart: View {
    let summary: PeriodSummary

    private func key(_ index: Int) -> String { String(index) }

    private var labeledKeys: [String] {
        summary.buckets.indices.filter { summary.buckets[$0].label != nil }.map(key)
    }

    private func label(forKey key: String) -> String {
        guard let index = Int(key), summary.buckets.indices.contains(index) else { return "" }
        return summary.buckets[index].label ?? ""
    }

    var body: some View {
        let top = max(summary.buckets.map(\.miles).max() ?? 0, 0.1)
        let keys = summary.buckets.indices.map(key)
        return Chart {
            ForEach(Array(summary.buckets.enumerated()), id: \.offset) { index, bucket in
                // Faint full-height track behind every bucket, so empty days read as empty.
                BarMark(x: .value("Bucket", key(index)), yStart: .value("Track", 0), yEnd: .value("Track", top))
                    .foregroundStyle(Color.secondary.opacity(0.1))
                    .cornerRadius(2)
                BarMark(x: .value("Bucket", key(index)), yStart: .value("Start", 0), yEnd: .value("Miles", bucket.miles))
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
                    if let key = value.as(String.self) { Text(label(forKey: key)) }
                }
            }
        }
        .frame(height: 70)
    }
}

#Preview("Period summary") {
    PreviewPeriodSummaryCard()
}

private struct PreviewPeriodSummaryCard: View {
    @State private var period = GroupingPeriod.week
    private let container = PreviewSupport.container()

    var body: some View {
        PeriodSummaryCard(
            period: $period,
            summary: PeriodSummary.compute(PreviewSupport.workouts(in: container), period: period)
        )
        .modelContainer(container)
        .padding()
    }
}
