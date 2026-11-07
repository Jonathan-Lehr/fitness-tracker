import SwiftUI

/// A past (or the current) calendar week, month or year chosen from a Log section header.
struct PastPeriodSelection: Identifiable, Hashable {
    let period: GroupingPeriod
    let start: Date
    var id: String { "\(period.rawValue)-\(start.timeIntervalSinceReferenceDate)" }
}

/// Modal summary card for one calendar period, compared with the calendar period before it.
/// Read-only: it only summarizes the workouts it's given.
struct PastPeriodSummaryView: View {
    let selection: PastPeriodSelection
    let workouts: [Workout]
    var filtered: Bool = false

    @Environment(\.dismiss) private var dismiss

    private var summary: PeriodSummary {
        PeriodSummary.computeCalendar(workouts, period: selection.period, containing: selection.start)
    }

    var body: some View {
        let s = summary
        NavigationStack {
            List {
                Section {
                    PeriodSummaryCard(period: .constant(selection.period), summary: s,
                                      filtered: filtered, showsPeriodPicker: false)
                } footer: {
                    Text("Compared with the \(s.comparisonText).")
                }
            }
            .navigationTitle(s.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 620, idealWidth: 680, minHeight: 300, idealHeight: 340)
        #endif
    }
}
