import SwiftUI
import Charts

struct PeriodSummaryCard: View {
    @Binding var period: GroupingPeriod
    let summary: PeriodSummary
    var filtered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Period", selection: $period) {
                ForEach(GroupingPeriod.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            #if os(macOS)
            HStack(alignment: .center, spacing: 28) {
                hero
                Divider().frame(height: 70)
                stats.fixedSize()
                chart.frame(minWidth: 220, maxWidth: .infinity)
            }
            #else
            HStack(alignment: .bottom) {
                hero
                Spacer(minLength: 16)
                chart.frame(minWidth: 120, maxWidth: 200)
            }
            stats
            #endif
        }
        .padding(.vertical, 6)
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
                Text(String(format: "%.1f", summary.current.miles))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("mi").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
            }
            Text(summary.deltaText)
                .font(.caption.weight(.medium))
                .foregroundStyle(summary.milesDelta > 0 ? Color.green : (summary.milesDelta < 0 ? Color.red : Color.secondary))
        }
    }

    private var stats: some View {
        #if os(macOS)
        HStack(alignment: .top, spacing: 28) {
            ForEach(PeriodSummary.Metric.allCases, id: \.self) { stat($0) }
        }
        #else
        // 2x2 on iPhone: four columns with deltas are too tight.
        // Two equal flexible columns spanning the full card width (no dead space on the right).
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16, alignment: .leading),
                            GridItem(.flexible(), spacing: 16, alignment: .leading)],
                  alignment: .leading, spacing: 12) {
            ForEach(PeriodSummary.Metric.allCases, id: \.self) { m in
                stat(m).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #endif
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
        .fixedSize(horizontal: true, vertical: false)
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
