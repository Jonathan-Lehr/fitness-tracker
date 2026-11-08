import SwiftUI
import SwiftData
import Charts

struct TrendsView: View {
    @Query(sort: \Workout.date) private var workouts: [Workout]
    @State private var period: GroupingPeriod = .week

    private struct Bucket: Identifiable {
        let start: Date
        let totals: Totals
        var id: Date { start }
    }

    /// Completed periods only; the in-progress period is shown separately in the comparison section.
    private var buckets: [Bucket] {
        let grouped = Dictionary(grouping: workouts) { period.start(of: $0.date) }
        return TrendsData.completedStarts(grouped.keys.sorted(), period: period, now: Date())
            .map { Bucket(start: $0, totals: Totals(grouped[$0] ?? [])) }
    }

    private struct WattsPoint: Identifiable {
        let start: Date
        let watts: Double
        var id: Date { start }
    }

    private var unit: Calendar.Component { period == .week ? .weekOfYear : .month }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Period", selection: $period) {
                        Text("Weekly").tag(GroupingPeriod.week)
                        Text("Monthly").tag(GroupingPeriod.month)
                    }
                    .pickerStyle(.segmented)

                    InProgressComparisonView(comparison: PartialPeriodComparison(workouts: workouts, period: period, now: Date()))

                    if let last = buckets.last {
                        Text("Charts show completed \(period == .week ? "weeks" : "months") through \(period.label(for: last.start)).")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    chart("Ride Time (min)") { b in BarMark(x: .value("Period", b.start, unit: unit), y: .value("Minutes", b.totals.minutes)) }
                    chart("Distance (mi)") { b in BarMark(x: .value("Period", b.start, unit: unit), y: .value("Miles", b.totals.miles)) }
                    chart("Calories") { b in BarMark(x: .value("Period", b.start, unit: unit), y: .value("Calories", b.totals.calories)) }
                    wattsChart
                }
                .padding()
            }
            .navigationTitle("Trends")
        }
    }

    /// Average Watts per period over rides that recorded watts (periods without watts are omitted),
    /// with the Y axis fitted to the plotted values (see `WattsAxis`).
    private var wattsChart: some View {
        let points = buckets.compactMap { b in b.totals.averageWatts.map { WattsPoint(start: b.start, watts: $0) } }
        let domain = WattsAxis.domain(for: points.map(\.watts))
        let xDomain = WattsAxis.dateDomain(periodStarts: points.map(\.start), period: period)
        return VStack(alignment: .leading) {
            Text("Average Watts").font(.headline)
            Chart(points) { p in
                LineMark(x: .value("Period", p.start, unit: unit), y: .value("Watts", p.watts))
                PointMark(x: .value("Period", p.start, unit: unit), y: .value("Watts", p.watts))
                    .symbolSize(20)
            }
            .chartYScale(domain: domain ?? 0...100)
            .chartXScale(domain: xDomain ?? Date.now...Date.now.addingTimeInterval(7 * 86_400))
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
            .overlay {
                if points.isEmpty {
                    Text("No rides with watts").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(height: 180)
        }
    }

    @ViewBuilder
    private func chart<C: ChartContent>(_ title: String, @ChartContentBuilder _ mark: @escaping (Bucket) -> C) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            Chart(buckets) { mark($0) }
                .frame(height: 180)
        }
    }
}
