import SwiftUI

struct CompareView: View {
    let earlier: Workout
    let later: Workout
    @Environment(\.dismiss) private var dismiss

    private struct Row: Identifiable {
        var id: String { name }
        let name: String
        let earlier: Double
        let later: Double
        let fractionLength: Int
    }

    private var rows: [Row] {
        [
            Row(name: "Duration (min)", earlier: earlier.durationMinutes, later: later.durationMinutes, fractionLength: 0),
            Row(name: "Distance (mi)", earlier: earlier.distanceMiles, later: later.distanceMiles, fractionLength: 2),
            Row(name: "Calories", earlier: Double(earlier.calories), later: Double(later.calories), fractionLength: 0),
            Row(name: "Elevation (ft)", earlier: Double(earlier.elevationFeet), later: Double(later.elevationFeet), fractionLength: 0),
            Row(name: "Avg RPM", earlier: Double(earlier.avgRPM), later: Double(later.avgRPM), fractionLength: 0),
            Row(name: "Avg Watts", earlier: Double(earlier.avgWatts), later: Double(later.avgWatts), fractionLength: 0),
            Row(name: "Incline Avg %", earlier: earlier.inclineAvg, later: later.inclineAvg, fractionLength: 1),
            Row(name: "Incline Max %", earlier: earlier.inclineMax, later: later.inclineMax, fractionLength: 1),
            Row(name: "Resistance Avg", earlier: Double(earlier.resistanceAvg), later: Double(later.resistanceAvg), fractionLength: 0),
            Row(name: "Resistance Max", earlier: Double(earlier.resistanceMax), later: Double(later.resistanceMax), fractionLength: 0),
        ]
    }

    var body: some View {
        NavigationStack {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("")
                    Text(earlier.date.formatted(date: .abbreviated, time: .omitted)).bold()
                    Text(later.date.formatted(date: .abbreviated, time: .omitted)).bold()
                    Text("Δ").bold()
                }
                Divider()
                ForEach(rows) { row in
                    let delta = row.later - row.earlier
                    GridRow {
                        Text(row.name).foregroundStyle(.secondary)
                        Text(formattedValue(row.earlier, fractionLength: row.fractionLength)).monospacedDigit()
                        Text(formattedValue(row.later, fractionLength: row.fractionLength)).monospacedDigit()
                        Text(formattedDelta(delta, fractionLength: row.fractionLength))
                            .monospacedDigit()
                            .foregroundStyle(delta == 0 ? Color.secondary : (delta > 0 ? Color.green : Color.red))
                    }
                }
            }
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle(earlier.title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 420)
        #endif
    }

    /// Whole-number stats use locale grouping; fractional stats (miles, incline) stay ungrouped.
    private func formattedValue(_ value: Double, fractionLength: Int) -> String {
        fractionLength == 0
            ? value.formattedWholeNumber()
            : value.formattedNumber(fractionLength: fractionLength)
    }

    private func formattedDelta(_ value: Double, fractionLength: Int) -> String {
        fractionLength == 0
            ? value.formattedSignedWholeNumber()
            : value.formattedSignedNumber(fractionLength: fractionLength)
    }
}
