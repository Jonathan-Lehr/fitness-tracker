import SwiftUI

/// Side-by-side stats for two efforts of the same program, grouped into sections, with the
/// change from the earlier workout to the later one.
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

/// Column widths shared by the header and every row so the values line up. The label column
/// just fits the longest label ("Avg watts"); the two value columns split whatever width is left.
private struct CompareColumns: DynamicProperty {
    @ScaledMetric(relativeTo: .body) var labelWidth: CGFloat = 76
    @ScaledMetric(relativeTo: .body) var changeWidth: CGFloat = 68
    /// Extra space before the Change column, so the later workout's values and date don't crowd it.
    @ScaledMetric(relativeTo: .body) var changeLeadingGap: CGFloat = 10
}

/// The first section's header: its title, then the two workout dates and "Change" over their columns.
private struct CompareColumnsHeader: View {
    let title: String
    let earlierDate: Date
    let laterDate: Date
    private let columns = CompareColumns()

    /// Month and day when both workouts are in the same year; otherwise the short numeric date
    /// ("10/27/25"), which includes the year and still fits the column.
    private var dateFormat: Date.FormatStyle {
        let calendar = Calendar.app
        let sameYear = calendar.component(.year, from: earlierDate) == calendar.component(.year, from: laterDate)
        return sameYear
            ? .dateTime.month(.abbreviated).day()
            : .dateTime.month(.defaultDigits).day().year(.twoDigits)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .frame(width: columns.labelWidth, alignment: .leading)
            dateColumn(earlierDate)
            dateColumn(laterDate)
            Text("Change")
                .frame(width: columns.changeWidth, alignment: .trailing)
                .padding(.leading, columns.changeLeadingGap)
        }
    }

    private func dateColumn(_ date: Date) -> some View {
        Text(date.formatted(dateFormat))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .trailing)
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
                .frame(width: columns.labelWidth, alignment: .leading)
            valueText(stat.earlierValue)
            valueText(stat.laterValue)
            changePill
                .frame(width: columns.changeWidth, alignment: .trailing)
                .padding(.leading, columns.changeLeadingGap)
        }
        .accessibilityElement(children: .combine)
    }

    private func valueText(_ value: Double) -> some View {
        Text(stat.formatValue(value, .current))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .trailing)
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
