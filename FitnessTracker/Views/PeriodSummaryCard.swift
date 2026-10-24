import SwiftUI
import Charts

struct PeriodSummaryCard: View {
    @Binding var period: GroupingPeriod
    let summary: PeriodSummary
    var filtered: Bool = false

    static let columnSpacing: CGFloat = 16
    /// Measured card width; drives the layout instead of size classes (a non-Max iPhone in
    /// landscape reports a compact horizontal size class).
    @State private var cardWidth: CGFloat = 0
    /// Measured content width of the Elevation stat (the chart's trailing edge stops there).
    @State private var elevationWidth: CGFloat = 0

    /// Width of one of the four equal stat columns.
    private var wideColumnWidth: CGFloat {
        max(0, (cardWidth - 3 * Self.columnSpacing) / 4)
    }

    /// Columns 2–3 plus the Elevation content, so the chart spans Time…Elevation.
    private var wideChartWidth: CGFloat {
        let col = wideColumnWidth
        let elevation = elevationWidth > 0 ? min(elevationWidth, col) : col
        return max(0, 2 * col + 2 * Self.columnSpacing + elevation)
    }

    #if os(iOS)
    @Environment(\.verticalSizeClass) private var vSize
    private var useWideLayout: Bool { vSize == .compact || cardWidth > 600 }
    #else
    private let useWideLayout = true
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Period", selection: $period) {
                ForEach(GroupingPeriod.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if useWideLayout {
                // Wide (Mac, iPhone landscape): a 4-column grid. Top row: hero in column 1, chart
                // from column 2's leading edge to the end of the Elevation stat's content;
                // bottom row: one stat per column.
                HStack(alignment: .bottom, spacing: Self.columnSpacing) {
                    hero.frame(width: wideColumnWidth, alignment: .leading)
                    chart.frame(width: wideChartWidth)
                    Spacer(minLength: 0)
                }
                statsGrid(columns: 4)
            } else {
                // Narrow (iPhone portrait): miles + chart, then a 2x2 grid.
                HStack(alignment: .bottom) {
                    hero.layoutPriority(1)
                    Spacer(minLength: 16)
                    chart.frame(minWidth: 80, maxWidth: 200)
                }
                statsGrid(columns: 2)
            }
        }
        .padding(.vertical, 6)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { cardWidth = $0 }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(summary.title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                if filtered {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.caption).foregroundStyle(.secondary)
                        .help("Filters applied")
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(PeriodSummary.milesNumber(summary.current.miles))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                Text("mi").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
            }
            Text(summary.deltaText)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(summary.milesDelta > 0 ? Color.green : (summary.milesDelta < 0 ? Color.red : Color.secondary))
        }
    }

    /// Stats in equal flexible columns spanning the full card width, each leading-aligned.
    private func statsGrid(columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.columnSpacing, alignment: .leading),
                                 count: columns),
                  alignment: .leading, spacing: 12) {
            ForEach(PeriodSummary.Metric.allCases, id: \.self) { m in
                stat(m)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { w in
                        if m == .elevation { elevationWidth = w }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func value(_ m: PeriodSummary.Metric) -> (String, String) {
        let t = summary.current
        switch m {
        case .rides: return ("\(t.count)", "Rides")
        case .time: return (t.minutes.minutesText, "Time")
        case .calories: return ("\(t.calories)", "Calories")
        case .elevation: return ("\(t.feet) ft", "Elevation")
        }
    }

    private func stat(_ m: PeriodSummary.Metric) -> some View {
        let (v, label) = value(m)
        let d = summary.delta(m)
        return VStack(alignment: .leading, spacing: 1) {
            Text(v).font(.headline.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(summary.deltaText(m))
                .font(.caption2.weight(.medium)).monospacedDigit()
                .foregroundStyle(d > 0 ? Color.green : (d < 0 ? Color.red : Color.secondary))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityElement(children: .combine)
    }

    private var axisStride: (component: Calendar.Component, count: Int, format: Date.FormatStyle) {
        switch summary.period {
        case .week: (.day, 1, .dateTime.weekday(.narrow))
        case .month: (.day, 7, .dateTime.day())
        case .year: (.month, 3, .dateTime.month(.narrow))
        }
    }

    /// Midpoints of the labeled buckets, so ticks and labels sit under the bar centers.
    private var axisDates: [Date] {
        let cal = Calendar.current
        let unit = PeriodSummary.bucketComponent(for: summary.period)
        return summary.buckets.enumerated().compactMap { i, b in
            guard i % axisStride.count == 0,
                  let next = cal.date(byAdding: unit, value: 1, to: b.start) else { return nil }
            return b.start.addingTimeInterval(next.timeIntervalSince(b.start) / 2)
        }
    }

    private var chart: some View {
        let unit = PeriodSummary.bucketComponent(for: summary.period)
        let top = max(summary.buckets.map(\.miles).max() ?? 0, 0.1)
        return Chart {
            // Faint full-height track behind every bucket, so empty days read as empty.
            ForEach(summary.buckets) { b in
                BarMark(x: .value("Date", b.start, unit: unit), yStart: .value("Track", 0), yEnd: .value("Track", top))
                    .foregroundStyle(Color.secondary.opacity(0.1))
                    .cornerRadius(2)
            }
            ForEach(summary.buckets) { b in
                BarMark(x: .value("Date", b.start, unit: unit), y: .value("Miles", b.miles))
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(2)
            }
            // Hairline baseline.
            RuleMark(y: .value("Baseline", 0))
                .lineStyle(StrokeStyle(lineWidth: 0.75))
                .foregroundStyle(Color.secondary.opacity(0.5))
        }
        .chartYScale(domain: 0...top)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: axisDates) { _ in
                AxisTick(centered: true, length: 4, stroke: StrokeStyle(lineWidth: 0.75))
                    .foregroundStyle(Color.secondary.opacity(0.6))
                AxisValueLabel(format: axisStride.format, centered: true)
            }
        }
        .frame(height: 70)
    }
}
