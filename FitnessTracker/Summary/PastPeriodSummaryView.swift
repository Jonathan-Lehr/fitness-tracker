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

    /// Whether an earlier period exists that isn't before the calendar period containing the
    /// earliest workout (`nil` = no workouts: no earlier period).
    func hasPrevious(earliest: Date?, calendar: Calendar = .app) -> Bool {
        guard let earliest else { return false }
        return start > period.start(of: earliest, calendar: calendar)
    }

    /// This selection kept within [period of `earliest`, current period]; unchanged if already inside.
    func clamped(earliest: Date?, now: Date = .now, calendar: Calendar = .app) -> PastPeriodSelection {
        var clampedStart = period.start(of: start, calendar: calendar)
        clampedStart = min(clampedStart, period.start(of: now, calendar: calendar))
        if let earliest { clampedStart = max(clampedStart, period.start(of: earliest, calendar: calendar)) }
        return PastPeriodSelection(period: period, start: clampedStart)
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

    /// Earliest workout in the (filtered) data the sheet summarizes; bounds Previous.
    private var earliest: Date? { workouts.map(\.date).min() }

    /// The shown period: the selection clamped to [earliest workout's period, current period],
    /// so it stays valid if workouts are deleted or edited while the sheet is open.
    private var current: PastPeriodSelection { selection.clamped(earliest: earliest) }
    private var canGoBack: Bool { current.hasPrevious(earliest: earliest) }
    private var canGoForward: Bool { current.hasNext() }

    private var unit: String { current.period.rawValue }

    private func go(_ offset: Int) {
        guard offset < 0 ? canGoBack : canGoForward else { return }
        withAnimation(.default) { selection = current.moved(by: offset) }
    }

    private var summary: PeriodSummary {
        PeriodSummary.computeCalendar(workouts, period: current.period, containing: current.start)
    }

    private var periodWorkouts: [Workout] {
        PeriodSummary.calendarWorkouts(workouts, period: current.period, containing: current.start)
    }

    var body: some View {
        let periodSummary = summary
        let shownWorkouts = periodWorkouts
        NavigationStack {
            List {
                Section {
                    PeriodSummaryCard(period: .constant(current.period), summary: periodSummary,
                                      filtered: filtered, showsPeriodPicker: false)
                } footer: {
                    Text("Compared with the \(periodSummary.comparisonText).")
                }
                Section("Workouts") {
                    if shownWorkouts.isEmpty {
                        ContentUnavailableView("No Workouts", systemImage: "bicycle",
                                               description: Text(filtered ? "No workouts this \(unit.lowercased()) match the filters."
                                                                 : "No workouts this \(unit.lowercased())."))
                    }
                    ForEach(shownWorkouts) { workout in
                        NavigationLink(value: workout) { WorkoutRow(workout: workout) }
                    }
                }
            }
            .navigationTitle(periodSummary.title)
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            // Bottom toolbar: a bar-material strip pinned below the list on iOS and macOS, with
            // plain SwiftUI buttons so .disabled reliably blocks touches, highlight and shortcuts.
            // (Custom title + chevron labels inside a system bottomBar ToolbarItemGroup kept
            // highlighting on touch while disabled.)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PeriodNavigationBar(
                    unit: unit,
                    canGoBack: canGoBack,
                    canGoForward: canGoForward,
                    onPrevious: { go(-1) },
                    onNext: { go(1) }
                )
            }
        }
        #if os(iOS)
        // Portrait-only on iPhone while the sheet is shown (including after an interactive
        // swipe-down dismissal, which also triggers onDisappear); other screens keep landscape.
        .onAppear { OrientationLock.setPortraitOnly(true) }
        .onDisappear { OrientationLock.setPortraitOnly(false) }
        #endif
        #if os(macOS)
        .frame(minWidth: 620, idealWidth: 680, minHeight: 480, idealHeight: 560)
        #endif
    }
}

/// Previous / Next bar pinned below the past-period summary list.
private struct PeriodNavigationBar: View {
    let unit: String
    let canGoBack: Bool
    let canGoForward: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                previousButton
                Spacer()
                nextButton
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
        }
        .background(.bar)
    }

    private var previousButton: some View {
        Button(action: onPrevious) {
            Label("Previous", systemImage: "chevron.left").labelStyle(.titleAndIcon)
        }
        .accessibilityLabel("Previous \(unit)")
        .keyboardShortcut(.leftArrow, modifiers: [])
        .disabled(!canGoBack)
    }

    private var nextButton: some View {
        Button(action: onNext) {
            HStack(spacing: 4) {
                Text("Next")
                Image(systemName: "chevron.right")
            }
        }
        .accessibilityLabel("Next \(unit)")
        .keyboardShortcut(.rightArrow, modifiers: [])
        .disabled(!canGoForward)
    }
}
