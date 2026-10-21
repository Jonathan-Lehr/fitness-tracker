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

    private var buckets: [Bucket] {
        let grouped = Dictionary(grouping: workouts) { period.start(of: $0.date) }
        return grouped.keys.sorted().map { Bucket(start: $0, totals: Totals(grouped[$0] ?? [])) }
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

                    chart("Ride Time (min)") { b in BarMark(x: .value("Period", b.start, unit: unit), y: .value("Minutes", b.totals.minutes)) }
                    chart("Distance (mi)") { b in BarMark(x: .value("Period", b.start, unit: unit), y: .value("Miles", b.totals.miles)) }
                    chart("Calories") { b in BarMark(x: .value("Period", b.start, unit: unit), y: .value("Calories", b.totals.calories)) }
                    chart("Average Watts") { b in
                        LineMark(x: .value("Period", b.start, unit: unit), y: .value("Watts", b.totals.avgWatts))
                    }
                }
                .padding()
            }
            .navigationTitle("Trends")
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
