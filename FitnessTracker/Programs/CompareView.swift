import SwiftUI

/// Side-by-side stats for two efforts of the same program, grouped into sections, with the
/// change from the earlier ride to the later one.
struct CompareView: View {
    let earlier: Workout
    let later: Workout
    @Environment(\.dismiss) private var dismiss

    private var sections: [ComparedSection] {
        ComparedSection.all(earlier: earlier, later: later)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.stats) { stat in
                            ComparedStatRow(stat: stat)
                        }
                    } header: {
                        if section.title == sections.first?.title {
                            CompareColumnsHeader(title: section.title, earlierDate: earlier.date, laterDate: later.date)
                        } else {
                            Text(section.title)
                        }
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
            .navigationTitle(earlier.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 520)
        #endif
    }
}

/// Column widths shared by the header and every row so the values line up.
private struct CompareColumns: DynamicProperty {
    @ScaledMetric(relativeTo: .body) var valueWidth: CGFloat = 72
    @ScaledMetric(relativeTo: .body) var changeWidth: CGFloat = 64
}

/// The first section's header: its title, then the two ride dates and "Change" over their columns.
private struct CompareColumnsHeader: View {
    let title: String
    let earlierDate: Date
    let laterDate: Date
    private let columns = CompareColumns()

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text(title)
            Spacer(minLength: 0)
            dateColumn(earlierDate)
            dateColumn(laterDate)
            Text("Change")
                .frame(width: columns.changeWidth, alignment: .trailing)
        }
    }

    private func dateColumn(_ date: Date) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(date.formatted(.dateTime.month(.abbreviated).day()))
            Text(date.formatted(.dateTime.year()))
                .foregroundStyle(.tertiary)
        }
        .frame(width: columns.valueWidth, alignment: .trailing)
    }
}

/// One stat: label, both values, and the change as a small arrow pill.
private struct ComparedStatRow: View {
    let stat: ComparedStat
    private let columns = CompareColumns()

    private var changeColor: Color {
        guard stat.preference == .higherIsBetter else { return .secondary }
        switch stat.trend {
        case .up: return .green
        case .down: return .red
        case .unchanged: return .secondary
        }
    }

    private var arrowName: String? {
        switch stat.trend {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .unchanged: nil
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(stat.label)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            valueText(stat.earlierValue)
            valueText(stat.laterValue)
            changePill
                .frame(width: columns.changeWidth, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func valueText(_ value: Double) -> some View {
        Text(stat.formatValue(value, .current))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: columns.valueWidth, alignment: .trailing)
    }

    private var changePill: some View {
        HStack(spacing: 2) {
            if let arrowName {
                Image(systemName: arrowName)
                    .imageScale(.small)
                    .fontWeight(.bold)
            }
            Text(stat.changeText())
                .monospacedDigit()
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(changeColor)
        .lineLimit(1)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(changeColor.opacity(0.15), in: Capsule())
    }
}

#Preview("Compare") {
    let container = PreviewSupport.container()
    let workouts = PreviewSupport.workouts(in: container)
    CompareView(earlier: workouts[0], later: workouts[1])
        .modelContainer(container)
}
