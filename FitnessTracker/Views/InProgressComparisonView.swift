import SwiftUI

/// Compact "so far" comparison of the in-progress period against the same elapsed portion of the previous one.
struct InProgressComparisonView: View {
    let comparison: PartialPeriodComparison

    private var noun: String { comparison.period.rawValue.lowercased() }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("This \(noun) so far").font(.headline)
                Spacer()
                Text("In progress")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(.orange.opacity(0.2), in: Capsule())
            }
            Text("\(Self.range(comparison.current)) vs same point last \(noun) (\(Self.range(comparison.previous)))")
                .font(.caption).foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("")
                    Text("So far").font(.caption).foregroundStyle(.secondary)
                    Text("Last \(noun)").font(.caption).foregroundStyle(.secondary)
                    Text("Change").font(.caption).foregroundStyle(.secondary)
                }
                row("Ride time", cur.minutes, prev.minutes) { $0.minutesText }
                row("Distance", cur.miles, prev.miles) { $0.milesText }
                row("Calories", Double(cur.calories), Double(prev.calories)) { "\(Int($0.rounded()))" }
                wattsRow
            }
            .font(.subheadline.monospacedDigit())
        }
        .padding()
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private var cur: Totals { comparison.currentTotals }
    private var prev: Totals { comparison.previousTotals }

    private func row(_ title: String, _ a: Double, _ b: Double, format: (Double) -> String) -> some View {
        GridRow {
            Text(title)
            Text(format(a))
            Text(format(b)).foregroundStyle(.secondary)
            Text(Self.change(a, b)).foregroundStyle(.secondary)
        }
    }

    private var wattsRow: some View {
        GridRow {
            Text("Avg Watts")
            Text(cur.averageWatts.map { "\(Int($0.rounded())) W" } ?? "— W")
            Text(prev.averageWatts.map { "\(Int($0.rounded())) W" } ?? "— W").foregroundStyle(.secondary)
            Text(cur.averageWatts.flatMap { a in prev.averageWatts.map { Self.change(a, $0) } } ?? "—")
                .foregroundStyle(.secondary)
        }
    }

    /// Percent change; "—" when the earlier value is zero (no meaningful percentage).
    static func change(_ a: Double, _ b: Double) -> String {
        guard b > 0 else { return "—" }
        let pct = (a - b) / b * 100
        return pct.formatted(.number.precision(.fractionLength(0)).sign(strategy: .always())) + "%"
    }

    static func range(_ i: DateInterval) -> String {
        let start = i.start.formatted(.dateTime.month(.abbreviated).day())
        let end = i.end.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        return "\(start) – \(end)"
    }
}
