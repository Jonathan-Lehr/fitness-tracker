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
                // Wide (Mac, iPhone landscape): a 4-column grid. Top row: hero in columns 1–2,
                // chart in columns 3–4; bottom row: one stat per column. The two halves use the
                // same spacing as the grid, so their edges line up with the stat columns.
                HStack(alignment: .bottom, spacing: Self.columnSpacing) {
                    hero.frame(maxWidth: .infinity, alignment: .leading)
                    chart.frame(maxWidth: .infinity)
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
                .minimumScaleFactor(0.7)
                .foregroundStyle(summary.milesDelta > 0 ? Color.green : (summary.milesDelta < 0 ? Color.red : Color.secondary))
        }
    }

    /// Stats in equal flexible columns spanning the full card width, each leading-aligned.
    private func statsGrid(columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.columnSpacing, alignment: .leading),
                                 count: columns),
                  alignment: .leading, spacing: 12) {
            ForEach(PeriodSummary.Metric.allCases, id: \.self) { m in
                stat(m).frame(maxWidth: .infinity, alignment: .leading)
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

    private var chart: some View {
        let unit = PeriodSummary.bucketComponent(for: summary.period)
        return Chart(summary.buckets) { b in
            BarMark(x: .value("Date", b.start, unit: unit), y: .value("Miles", b.miles))
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(2)
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: axisStride.component, count: axisStride.count)) { _ in
                AxisValueLabel(format: axisStride.format)
            }
        }
        .frame(height: 70)
    }
}
