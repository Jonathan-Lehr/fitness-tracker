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
    private func completedBuckets(now: Date) -> [Bucket] {
        let grouped = Dictionary(grouping: workouts) { period.start(of: $0.date) }
        return TrendsData.completedStarts(grouped.keys.sorted(), period: period, now: now)
            .map { Bucket(start: $0, totals: Totals(grouped[$0] ?? [])) }
    }

    private var unit: Calendar.Component { period == .week ? .weekOfYear : .month }

    var body: some View {
        let now = Date()
        let buckets = completedBuckets(now: now)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Period", selection: $period) {
                        Text("Weekly").tag(GroupingPeriod.week)
                        Text("Monthly").tag(GroupingPeriod.month)
                    }
                    .pickerStyle(.segmented)

                    InProgressComparisonView(comparison: PartialPeriodComparison(workouts: workouts, period: period, now: now))

                    if let last = buckets.last {
                        Text("Charts show completed \(period == .week ? "weeks" : "months") through \(period.label(for: last.start)).")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    chart("Ride Time (min)", buckets: buckets) { bucket in
                        BarMark(x: .value("Period", bucket.start, unit: unit), y: .value("Minutes", bucket.totals.minutes))
                    }
                    chart("Distance (mi)", buckets: buckets) { bucket in
                        BarMark(x: .value("Period", bucket.start, unit: unit), y: .value("Miles", bucket.totals.miles))
                    }
                    chart("Calories", buckets: buckets) { bucket in
                        BarMark(x: .value("Period", bucket.start, unit: unit), y: .value("Calories", bucket.totals.calories))
                    }
                    AverageWattsChart(points: wattPoints(from: buckets), period: period)
                }
                .padding()
            }
            .navigationTitle("Trends")
        }
    }

    private func wattPoints(from buckets: [Bucket]) -> [WattsAxis.Point] {
        buckets.compactMap { bucket in
            bucket.totals.averageWatts.map { WattsAxis.Point(start: bucket.start, watts: $0) }
        }
    }

    @ViewBuilder
    private func chart<C: ChartContent>(_ title: String, buckets: [Bucket],
                                       @ChartContentBuilder _ mark: @escaping (Bucket) -> C) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            Chart(buckets) { mark($0) }
                .frame(height: 180)
        }
    }
}

/// Average Watts per period over rides that recorded watts (periods without watts are omitted),
/// with the Y axis fitted to the plotted values (see `WattsAxis`).
private struct AverageWattsChart: View {
    let points: [WattsAxis.Point]
    let period: GroupingPeriod

    var body: some View {
        let domain = WattsAxis.domain(for: points.map(\.watts))
        let segments = WattsAxis.segments(points, period: period)
        let xDomain = WattsAxis.dateDomain(periodStarts: points.map(\.start), period: period)
        return VStack(alignment: .leading) {
            Text("Average Watts").font(.headline)
            Chart {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    ForEach(segment.points, id: \.start) { point in
                        LineMark(x: .value("Period", point.start), y: .value("Watts", point.watts),
                                 series: .value("Segment", index))
                            .lineStyle(segment.isGap ? StrokeStyle(lineWidth: 1.5, dash: [4, 4]) : StrokeStyle(lineWidth: 2))
                            .foregroundStyle(segment.isGap ? Color.accentColor.opacity(0.6) : Color.accentColor)
                    }
                }
                ForEach(points, id: \.start) { point in
                    PointMark(x: .value("Period", point.start), y: .value("Watts", point.watts))
                        .symbolSize(20)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .chartYScale(domain: domain ?? 0...100)
            // Points sit at period starts on the domain ends; inset only enough pixels to keep dots unclipped.
            .chartXScale(domain: xDomain ?? Date.now...Date.now.addingTimeInterval(7 * 86_400),
                         range: .plotDimension(padding: 6))
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
            .overlay {
                if points.isEmpty {
                    Text("No rides with watts").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(height: 180)
            if segments.contains(where: \.isGap) {
                Text("Dashed lines span periods without Watts data; they are not measured values.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
