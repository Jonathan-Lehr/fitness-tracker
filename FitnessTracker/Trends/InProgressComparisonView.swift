import SwiftUI

/// Compact "so far" comparison of the in-progress period against the same elapsed portion of the previous one.
struct InProgressComparisonView: View {
    let comparison: PartialPeriodComparison

    private var noun: String { comparison.period.rawValue.lowercased() }
    private var currentTotal: Totals { comparison.currentTotals }
    private var previousTotal: Totals { comparison.previousTotals }

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

            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                GridRow {
                    Text("")
                    Text("So far").font(.caption).foregroundStyle(.secondary).dataColumn()
                    Text("Last \(noun)").font(.caption).foregroundStyle(.secondary).dataColumn()
                    Text("Change").font(.caption).foregroundStyle(.secondary).changeColumn()
                }
                row("Ride time", currentTotal.minutes, previousTotal.minutes) { $0.formattedMinutes() }
                row("Distance", currentTotal.miles, previousTotal.miles) { $0.formattedMilesWithUnit() }
                row("Calories", Double(currentTotal.calories), Double(previousTotal.calories)) { $0.formattedWholeNumber() }
                wattsRow
            }
            .font(.subheadline.monospacedDigit())
        }
        .padding()
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private func row(_ title: String, _ currentValue: Double, _ previousValue: Double, format: (Double) -> String) -> some View {
        GridRow {
            Text(title).lineLimit(1).fixedSize()
            Text(format(currentValue)).dataColumn()
            Text(format(previousValue)).foregroundStyle(.secondary).dataColumn()
            Text(Self.change(currentValue, previousValue)).foregroundStyle(.secondary).changeColumn()
        }
    }

    private var wattsRow: some View {
        GridRow {
            Text("Avg Watts").lineLimit(1).fixedSize()
            Text(formattedAverageWatts(currentTotal.averageWatts, placeholder: "— W")).dataColumn()
            Text(formattedAverageWatts(previousTotal.averageWatts, placeholder: "— W")).foregroundStyle(.secondary).dataColumn()
            Text(currentTotal.averageWatts.flatMap { currentWatts in previousTotal.averageWatts.map { Self.change(currentWatts, $0) } } ?? "—")
                .foregroundStyle(.secondary).changeColumn()
        }
    }

    /// Percent change; "—" when the earlier value is zero (no meaningful percentage).
    static func change(_ current: Double, _ previous: Double, locale: Locale = .current) -> String {
        guard previous > 0 else { return "—" }
        let percent = (current - previous) / previous * 100
        return percent.formattedSignedWholeNumber(locale: locale) + "%"
    }

    static func range(_ interval: DateInterval) -> String {
        let start = interval.start.formatted(.dateTime.month(.abbreviated).day())
        let end = interval.end.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        return "\(start) – \(end)"
    }
}

private extension View {
    /// Data columns share the card width left after the label column, right-aligned so digits line up.
    /// Text may shrink slightly rather than truncate on narrow iPhones or large Dynamic Type sizes.
    func dataColumn() -> some View {
        lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    /// The short Change column (e.g. "+12%") gets a moderate minimum width (72 pt) instead of an equal share,
    /// so the gaps between So far, Last and Change values look about even (equal shares left Last looking
    /// too far left; 56 pt pushed it too far right).
    func changeColumn() -> some View {
        lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(minWidth: 72, alignment: .trailing)
    }
}
