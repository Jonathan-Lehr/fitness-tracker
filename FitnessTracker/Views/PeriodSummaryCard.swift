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
                stats
                chart.frame(minWidth: 220, maxWidth: .infinity)
            }
            #else
            HStack(alignment: .bottom) {
                hero
                Spacer(minLength: 12)
                chart.frame(width: 140)
            }
            stats
            #endif
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
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
        HStack(spacing: 0) {
            stat("\(summary.current.count)", "Rides")
            stat(summary.current.minutes.minutesText, "Time")
            stat("\(summary.current.calories)", "Calories")
            stat("\(summary.current.feet) ft", "Elevation")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
