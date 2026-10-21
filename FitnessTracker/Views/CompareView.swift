import SwiftUI

struct CompareView: View {
    let a: Workout   // earlier
    let b: Workout   // later
    @Environment(\.dismiss) private var dismiss

    private struct Row: Identifiable {
        let id = UUID()
        let name: String, a: Double, b: Double, format: String, higherIsBetter: Bool
    }

    private var rows: [Row] {
        [
            Row(name: "Duration (min)", a: a.durationMinutes, b: b.durationMinutes, format: "%.0f", higherIsBetter: true),
            Row(name: "Distance (mi)", a: a.distanceMiles, b: b.distanceMiles, format: "%.2f", higherIsBetter: true),
            Row(name: "Calories", a: Double(a.calories), b: Double(b.calories), format: "%.0f", higherIsBetter: true),
            Row(name: "Elevation (ft)", a: Double(a.elevationFeet), b: Double(b.elevationFeet), format: "%.0f", higherIsBetter: true),
            Row(name: "Avg RPM", a: Double(a.avgRPM), b: Double(b.avgRPM), format: "%.0f", higherIsBetter: true),
            Row(name: "Avg Watts", a: Double(a.avgWatts), b: Double(b.avgWatts), format: "%.0f", higherIsBetter: true),
            Row(name: "Incline Avg %", a: a.inclineAvg, b: b.inclineAvg, format: "%.1f", higherIsBetter: true),
            Row(name: "Incline Max %", a: a.inclineMax, b: b.inclineMax, format: "%.1f", higherIsBetter: true),
            Row(name: "Resistance Avg", a: Double(a.resistanceAvg), b: Double(b.resistanceAvg), format: "%.0f", higherIsBetter: true),
            Row(name: "Resistance Max", a: Double(a.resistanceMax), b: Double(b.resistanceMax), format: "%.0f", higherIsBetter: true),
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
                        Text(String(format: r.format, r.a)).monospacedDigit()
                        Text(String(format: r.format, r.b)).monospacedDigit()
                        Text((delta >= 0 ? "+" : "") + String(format: r.format, delta))
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
}
