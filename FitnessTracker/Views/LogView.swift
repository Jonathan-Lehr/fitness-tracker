import SwiftUI
import SwiftData

struct LogFilter: Equatable {
    var useDateRange = false
    var startDate = Calendar.app.date(byAdding: .month, value: -3, to: .now) ?? .now
    var endDate = Date.now
    var programTitle: String? = nil
    var type: WorkoutType? = nil
    var minWatts = 0

    var isActive: Bool { useDateRange || programTitle != nil || type != nil || minWatts > 0 }

    func matches(_ w: Workout) -> Bool {
        if useDateRange {
            let cal = Calendar.app
            let lo = cal.startOfDay(for: startDate)
            let hi = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: endDate)) ?? endDate
            if w.date < lo || w.date >= hi { return false }
        }
        if let programTitle, w.title != programTitle { return false }
        if let type, w.type != type { return false }
        if w.avgWatts < minWatts { return false }
        return true
    }
}

struct LogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @State private var period: GroupingPeriod = .week
    @State private var filter = LogFilter()
    @State private var showFilters = false
    @State private var showAdd = false
    @State private var showDebug = false
    @State private var showBackup = false
    @State private var pastPeriod: PastPeriodSelection?
    @AppStorage("logLayout") private var layout: LogLayout = .list
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var wideGrid: Bool { sizeClass == .regular }
    #else
    private let wideGrid = true
    #endif

    private var layoutPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .navigation
        #endif
    }

    private var filtered: [Workout] { workouts.filter(filter.matches) }

    private var sections: [(start: Date, workouts: [Workout])] {
        let grouped = Dictionary(grouping: filtered) { period.start(of: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            Group {
                listBody
            }
            .navigationTitle("Rides")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .toolbar {
                // Leading placement puts the control in its own group, away from Add/Filters/More.
                // On iOS 26+ the shared glass background is hidden so the segmented control isn't
                // wrapped in the toolbar's button chrome (the earlier "button within a button").
                ToolbarItem(placement: layoutPlacement) {
                    Picker("Layout", selection: $layout) {
                        ForEach(LogLayout.allCases) { l in
                            Label(l.label, systemImage: l.systemImage).tag(l)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelStyle(.iconOnly)
                    .help("Show rides as a list or a grid")
                }
                .hideSharedToolbarBackgroundIfAvailable()
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Label("Add Ride", systemImage: "plus") }
                }
                ToolbarItem {
                    Button { showFilters = true } label: {
                        Label("Filters", systemImage: filter.isActive
                              ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem {
                    Menu {
                        Button { showBackup = true } label: { Label("Backup & Restore…", systemImage: "externaldrive") }
                        #if DEBUG
                        Button { showDebug = true } label: { Label("Debug…", systemImage: "ladybug") }
                        #endif
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showAdd) { AddRideView() }
            .sheet(isPresented: $showBackup) { BackupView() }
            .sheet(item: $pastPeriod) { sel in
                PastPeriodSummaryView(selection: sel, workouts: filtered, filtered: filter.isActive)
            }
            .sheet(isPresented: $showFilters) { FilterView(filter: $filter.animation(.default)) }
            #if DEBUG
            .sheet(isPresented: $showDebug) { DebugMenuView() }
            #endif
        }
    }

    private var summaryCard: some View {
        PeriodSummaryCard(period: $period,
                          summary: PeriodSummary.compute(filtered, period: period),
                          filtered: filter.isActive)
    }

    private func header(for start: Date, workouts: [Workout]) -> some View {
        // Tapping a section header opens that calendar period's summary card.
        Button {
            pastPeriod = PastPeriodSelection(period: period, start: start)
        } label: {
            SectionHeader(title: period.label(for: start), totals: Totals(workouts),
                          showsDisclosure: true)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows the summary for this \(period.rawValue.lowercased())")
    }

    private var emptyState: some View {
        ContentUnavailableView("No Rides", systemImage: "bicycle",
                               description: Text(filter.isActive ? "No rides match the filters." : "Add a ride to get started."))
    }

    /// One List for both modes: the summary card, empty state and period headers are the same
    /// views with the same list style, so they keep identical size and position when switching.
    /// Only each period's rows change (ride rows vs. one full-bleed grid row).
    private var listBody: some View {
        List {
            // Its own section, so the card uses the list's row background, corner radius
            // and insets on iOS (inset grouped) and macOS, lining up with the rows below.
            Section {
                summaryCard
                    #if os(macOS)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: NSColor.alternatingContentBackgroundColors.last ?? .controlBackgroundColor))
                            .padding(.horizontal, 6)
                    )
                    #endif
            }

            if sections.isEmpty { emptyState }
            ForEach(sections, id: \.start) { section in
                Section {
                    if layout == .grid {
                        RideGridSection(workouts: section.workouts, wide: wideGrid) { context.delete($0) }
                            // Keep the List's default leading/trailing insets so day headers
                            // and cards line up with period section headers (and list-mode rows).
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(section.workouts) { w in
                            NavigationLink(value: w) { WorkoutRow(workout: w) }
                        }
                        .onDelete { offsets in
                            for i in offsets { context.delete(section.workouts[i]) }
                        }
                    }
                } header: {
                    header(for: section.start, workouts: section.workouts)
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset(alternatesRowBackgrounds: true))
        #endif
    }
}

struct SectionHeader: View {
    let title: String
    let totals: Totals
    /// Shows a chevron marking the header as tappable (opens the period's summary).
    var showsDisclosure = false
    /// Duration-weighted average watts (rides without watts skipped); "— W" if none recorded.
    private var wattsText: String {
        totals.averageWatts.map { "\(Int($0.rounded())) W" } ?? "— W"
    }
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text("\(totals.count) rides · \(totals.minutes.minutesText) · \(wattsText) · \(totals.feet) ft")
                    .font(.subheadline)
            }
            Spacer()
            Text(PeriodSummary.milesNumber(totals.miles) + " mi")
                .font(.headline.bold()).monospacedDigit()
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        // Non-hierarchical secondary: List headers already inherit a secondary style, so the
        // hierarchical `.secondary` resolved one level dimmer there than outside a List.
        .foregroundStyle(Color.secondary)
        .textCase(nil)
    }
}

struct WorkoutRow: View {
    let workout: Workout
    /// The Log's section headers already show the year, so rows omit it by default.
    var showYear = false

    private var dateText: String {
        let base = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()
        return workout.date.formatted(showYear ? base.year() : base)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.title).font(.body.weight(.semibold))
                Spacer()
                Text("\(workout.avgWatts) W").monospacedDigit().foregroundStyle(.orange)
            }
            HStack(spacing: 12) {
                Text(dateText)
                Text(workout.durationMinutes.minutesText)
                Text(workout.distanceMiles.milesText)
                Text("\(workout.calories) cal")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private extension ToolbarContent {
    /// Hides the Liquid Glass shared background when the SDK has it (iOS/macOS 26+), so a
    /// segmented Picker in the toolbar isn't wrapped in the toolbar's button chrome. No-op
    /// on the app's iOS 17 / macOS 14 deployment targets.
    @ToolbarContentBuilder
    func hideSharedToolbarBackgroundIfAvailable() -> some ToolbarContent {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
