import SwiftUI

struct CompareView: View {
    let a: Workout   // earlier
    let b: Workout   // later
    @Environment(\.dismiss) private var dismiss

    private struct Row: Identifiable {
        let id = UUID()
        let name: String, a: Double, b: Double, fractionLength: Int, higherIsBetter: Bool
    }

    private var rows: [Row] {
        [
            Row(name: "Duration (min)", a: a.durationMinutes, b: b.durationMinutes, fractionLength: 0, higherIsBetter: true),
            Row(name: "Distance (mi)", a: a.distanceMiles, b: b.distanceMiles, fractionLength: 2, higherIsBetter: true),
            Row(name: "Calories", a: Double(a.calories), b: Double(b.calories), fractionLength: 0, higherIsBetter: true),
            Row(name: "Elevation (ft)", a: Double(a.elevationFeet), b: Double(b.elevationFeet), fractionLength: 0, higherIsBetter: true),
            Row(name: "Avg RPM", a: Double(a.avgRPM), b: Double(b.avgRPM), fractionLength: 0, higherIsBetter: true),
            Row(name: "Avg Watts", a: Double(a.avgWatts), b: Double(b.avgWatts), fractionLength: 0, higherIsBetter: true),
            Row(name: "Incline Avg %", a: a.inclineAvg, b: b.inclineAvg, fractionLength: 1, higherIsBetter: true),
            Row(name: "Incline Max %", a: a.inclineMax, b: b.inclineMax, fractionLength: 1, higherIsBetter: true),
            Row(name: "Resistance Avg", a: Double(a.resistanceAvg), b: Double(b.resistanceAvg), fractionLength: 0, higherIsBetter: true),
            Row(name: "Resistance Max", a: Double(a.resistanceMax), b: Double(b.resistanceMax), fractionLength: 0, higherIsBetter: true),
        ]
    }

    var body: some View {
        NavigationStack {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("")
                    Text(a.date.formatted(date: .abbreviated, time: .omitted)).bold()
                    Text(b.date.formatted(date: .abbreviated, time: .omitted)).bold()
                    Text("Δ").bold()
                }
                Divider()
                ForEach(rows) { r in
                    let delta = r.b - r.a
                    GridRow {
                        Text(r.name).foregroundStyle(.secondary)
                        Text(formattedValue(r.a, fractionLength: r.fractionLength)).monospacedDigit()
                        Text(formattedValue(r.b, fractionLength: r.fractionLength)).monospacedDigit()
                        Text(formattedDelta(delta, fractionLength: r.fractionLength))
                            .monospacedDigit()
                            .foregroundStyle(delta == 0 ? Color.secondary : ((delta > 0) == r.higherIsBetter ? Color.green : Color.red))
                    }
                }
            }
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle(a.title)
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
