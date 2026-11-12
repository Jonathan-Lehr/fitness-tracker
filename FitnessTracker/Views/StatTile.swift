import SwiftUI

/// Rolling digits for numbers; a plain crossfade when Reduce Motion is on.
func numericContentTransition(value: Double, reduceMotion: Bool) -> ContentTransition {
    reduceMotion ? .opacity : .numericText(value: value)
}

/// A change shown under a stat, colored by direction: green up, yellow for a small dip,
/// red for a big drop, secondary when unchanged.
struct StatDelta {
    /// How a change compares with the previous value.
    enum Trend: Equatable {
        case up
        case unchanged
        case smallDip
        case bigDrop
    }

    /// A decline is a small dip while the new value is still at least this fraction of the previous one.
    static let smallDipThreshold = 0.7

    let text: String
    /// Signed change; drives the color and the rolling-digit animation.
    let value: Double
    /// The value being compared against. When it's unknown, every decline counts as a big drop.
    var previousValue: Double? = nil

    var trend: Trend {
        if value > 0 { return .up }
        if value == 0 { return .unchanged }
        guard let previousValue, previousValue > 0 else { return .bigDrop }
        let currentValue = previousValue + value
        return currentValue / previousValue >= Self.smallDipThreshold ? .smallDip : .bigDrop
    }

    var color: Color {
        switch trend {
        case .up: .green
        case .unchanged: .secondary
        case .smallDip: AppColor.smallDipYellow.color
        case .bigDrop: .red
        }
    }
}

/// One metric: value, label, and an optional delta. Shared by the period summary cards and the
/// workout detail card so their stat styling stays identical. The delta row appears only when
/// comparison data is available.
struct StatTile: View {
    let value: String
    let label: String
    var delta: StatDelta? = nil
    var numericValue: Double = 0
    /// Reports the value text's width (the period card uses it to size its landscape chart).
    var onValueWidthChange: ((CGFloat) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            valueText
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let delta {
                deltaText(delta)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
    }

    private var valueText: some View {
        Text(value)
            .font(.headline.weight(.semibold))
            .monospacedDigit()
            .contentTransition(numericContentTransition(value: numericValue, reduceMotion: reduceMotion))
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                onValueWidthChange?(width)
            }
    }

    private func deltaText(_ delta: StatDelta) -> some View {
        Text(delta.text)
            .contentTransition(numericContentTransition(value: delta.value, reduceMotion: reduceMotion))
            .font(.caption2.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(delta.color)
    }
}
