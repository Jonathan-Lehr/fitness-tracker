import SwiftUI

/// A past (or the current) calendar week, month or year chosen from a Log section header.
struct PastPeriodSelection: Identifiable, Hashable {
    let period: GroupingPeriod
    let start: Date
    var id: String { "\(period.rawValue)-\(start.timeIntervalSinceReferenceDate)" }

    /// The calendar period `offset` periods away (−1 previous, +1 next), normalized to its start
    /// (Monday, the 1st, January 1) in `calendar`'s local time.
    func moved(by offset: Int, calendar: Calendar = .app) -> PastPeriodSelection {
        let anchor = period.start(of: start, calendar: calendar)
        let shifted = calendar.date(byAdding: period.component, value: offset, to: anchor) ?? anchor
        return PastPeriodSelection(period: period, start: period.start(of: shifted, calendar: calendar))
    }

    /// Whether a next period exists that isn't after the current calendar period containing `now`.
    func hasNext(now: Date = .now, calendar: Calendar = .app) -> Bool {
        moved(by: 1, calendar: calendar).start <= period.start(of: now, calendar: calendar)
    }
}

/// Modal summary card for one calendar period, compared with the calendar period before it.
/// Read-only: it only summarizes the workouts it's given.
struct PastPeriodSummaryView: View {
    @State private var selection: PastPeriodSelection
    let workouts: [Workout]
    var filtered: Bool = false

    @Environment(\.dismiss) private var dismiss

    init(selection: PastPeriodSelection, workouts: [Workout], filtered: Bool = false) {
        _selection = State(initialValue: selection)
        self.workouts = workouts
        self.filtered = filtered
    }

    private var unit: String { selection.period.rawValue }

    private func go(_ offset: Int) {
        withAnimation(.default) { selection = selection.moved(by: offset) }
    }

    /// Previous / Next calendar period below the card: two equal-width prominent buttons;
    /// Next is disabled (dimmed) at the current period.
    private var navigation: some View {
        HStack(spacing: 12) {
            Button { go(-1) } label: {
                Label("Previous", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .accessibilityLabel("Previous \(unit)")
            .keyboardShortcut(.leftArrow, modifiers: [])
            Button { go(1) } label: {
                HStack(spacing: 6) { Text("Next"); Image(systemName: "chevron.right") }
                    .frame(maxWidth: .infinity)
            }
            .accessibilityLabel("Next \(unit)")
            .keyboardShortcut(.rightArrow, modifiers: [])
            .disabled(!selection.hasNext())
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .labelStyle(.titleAndIcon)
        .font(.body.weight(.semibold))
        .textCase(nil)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
    }

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
                    VStack(spacing: 12) {
                        Text("Compared with the \(s.comparisonText).")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        navigation
                    }
                    .padding(.top, 8)
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
        #if os(iOS)
        // Portrait-only on iPhone while the sheet is shown (including after an interactive
        // swipe-down dismissal, which also triggers onDisappear); other screens keep landscape.
        .onAppear { OrientationLock.setPortraitOnly(true) }
        .onDisappear { OrientationLock.setPortraitOnly(false) }
        #endif
        #if os(macOS)
        .frame(minWidth: 620, idealWidth: 680, minHeight: 360, idealHeight: 400)
        #endif
    }
}
