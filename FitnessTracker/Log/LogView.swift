import SwiftUI
import SwiftData

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
    @AppStorage("logLayout") private var layout: LogLayout = .grid
    /// Explicit path so grid cards (several per List row) append exactly one destination.
    @State private var path = NavigationPath()
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

    var body: some View {
        let filteredWorkouts = workouts.filter(filter.matches)
        let sections = periodSections(from: filteredWorkouts)
        NavigationStack(path: $path) {
            listBody(sections: sections, filteredWorkouts: filteredWorkouts)
            .navigationTitle("Rides")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .toolbar {
                // Leading placement puts the control in its own group, away from Add/Filters/More.
                // On iOS 26+ the shared glass background is hidden so the segmented control isn't
                // wrapped in the toolbar's button chrome (the earlier "button within a button").
                ToolbarItem(placement: layoutPlacement) {
                    LogLayoutPicker(layout: $layout)
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
            .sheet(item: $pastPeriod) { selection in
                PastPeriodSummaryView(selection: selection, workouts: filteredWorkouts, filtered: filter.isActive)
            }
            .sheet(isPresented: $showFilters) { FilterView(filter: $filter.animation(.default)) }
            #if DEBUG
            .sheet(isPresented: $showDebug) { DebugMenuView() }
            #endif
        }
    }

    private func periodSections(from workouts: [Workout]) -> [(start: Date, workouts: [Workout])] {
        let grouped = Dictionary(grouping: workouts) { period.start(of: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    private func summaryCard(filteredWorkouts: [Workout]) -> some View {
        PeriodSummaryCard(period: $period,
                          summary: PeriodSummary.compute(filteredWorkouts, period: period),
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
    /// Grid (wide): one multi-column row. Grid (compact): one List row per day/card. List: ride rows.
    private func listBody(sections: [(start: Date, workouts: [Workout])],
                          filteredWorkouts: [Workout]) -> some View {
        List {
            // Its own section, so the card uses the list's row background, corner radius
            // and insets on iOS (inset grouped) and macOS, lining up with the rows below.
            Section {
                summaryCard(filteredWorkouts: filteredWorkouts)
                    #if os(macOS)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LogSurface.card)
                            .padding(.horizontal, 6)
                    )
                    #endif
            }

            if sections.isEmpty { emptyState }
            ForEach(sections, id: \.start) { section in
                Section {
                    sectionContent(for: section.workouts)
                } header: {
                    header(for: section.start, workouts: section.workouts)
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset(alternatesRowBackgrounds: true))
        #endif
    }

    @ViewBuilder
    private func sectionContent(for workouts: [Workout]) -> some View {
        if layout == .grid && !wideGrid {
            compactPhotoSection(workouts: workouts)
        } else if layout == .grid {
            // Mac / regular width: adaptive day columns in one List row.
            RideGridSection(workouts: workouts,
                             onOpen: { path.append($0) },
                             onDelete: { context.delete($0) })
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .selectionDisabled(true)
        } else {
            listSection(workouts: workouts)
        }
    }

    /// Compact iPhone photo-mode: one List row per ride, with a day header on the first ride of each day.
    @ViewBuilder
    private func compactPhotoSection(workouts: [Workout]) -> some View {
        // One period Section; one List row per ride. Date above first ride of
        // that day (outside the Button). Keep ~20pt horizontal insets (widths
        // already correct); restore default grouped row backgrounds so the
        // section reads as aligned with the summary.
        let days = DayGroup.group(workouts, date: \.date)
        ForEach(days, id: \.day) { day in
            ForEach(Array(day.items.enumerated()), id: \.element.persistentModelID) { index, workout in
                CompactPhotoRideRow(
                    day: day.day,
                    showDayHeader: index == 0,
                    isLastInSection: day.day == days.last?.day && index == day.items.count - 1,
                    workout: workout,
                    onOpen: { path.append(workout) },
                    onDelete: { context.delete(workout) }
                )
            }
        }
    }

    /// List-mode period section: text rows with swipe-to-delete.
    private func listSection(workouts: [Workout]) -> some View {
        ForEach(workouts) { workout in
            NavigationLink(value: workout) { WorkoutRow(workout: workout) }
        }
        .onDelete { offsets in
            for index in offsets { context.delete(workouts[index]) }
        }
    }
}

/// Toolbar layout toggle: list or grid. Sizing lives here so the control keeps a full hit
/// target; @ScaledMetric keeps it proportional with Dynamic Type.
private struct LogLayoutPicker: View {
    @Binding var layout: LogLayout
    /// Per-segment width for the layout toggle (HIG minimum hit target on iOS; Mac controls are smaller).
    #if os(iOS)
    @ScaledMetric(relativeTo: .body) private var segmentWidth: CGFloat = 44
    #else
    @ScaledMetric(relativeTo: .body) private var segmentWidth: CGFloat = 36
    #endif

    var body: some View {
        Picker("Layout", selection: $layout) {
            ForEach(LogLayout.allCases) { option in
                // Image-only labels: Label+iconOnly can collapse to near-zero width
                // in a toolbar segmented control under trailing-item pressure.
                Image(systemName: option.systemImage).tag(option)
                    .accessibilityLabel(option.label)
            }
        }
        .pickerStyle(.segmented)
        // A segmented control's fitted ("sizeToFit") width for icon-only segments is
        // just the glyphs plus a few points, which reads as cramped. fixedSize() kept
        // that fitted width, and the outer minWidth frame only padded around it without
        // widening the control. Sizing the Picker itself gives each segment a full hit
        // target; @ScaledMetric keeps it proportional with Dynamic Type.
        .frame(width: segmentWidth * CGFloat(LogLayout.allCases.count))
        .help("Show rides as a list or a grid")
        .accessibilityLabel("Layout")
    }
}

/// One compact photo-mode List row: optional day label + tappable card.
/// Extracted so `listBody` type-checks. Default grouped `listRowBackground` (same family as
/// the summary row) so the period section reads as aligned; horizontal insets stay ~20.
private struct CompactPhotoRideRow: View {
    let day: Date
    let showDayHeader: Bool
    /// Extra 6pt inside the section fill on the period's last ride row only.
    let isLastInSection: Bool
    let workout: Workout
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showDayHeader { DayHeader(day: day) }
            Button(action: onOpen) { RideRowCard(workout: workout) }
                .buttonStyle(.plain)
        }
        .listRowInsets(EdgeInsets(top: showDayHeader ? 8 : 4, leading: 20,
                                   bottom: isLastInSection ? 10 : 4, trailing: 20))
        // Native grouped row fill (LogSurface.card == secondarySystemGroupedBackground on iOS).
        .listRowBackground(LogSurface.card)
        .selectionDisabled(true)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    let totals: Totals
    /// Shows a chevron marking the header as tappable (opens the period's summary).
    var showsDisclosure = false
    /// Duration-weighted average watts (rides without watts skipped); "— W" if none recorded.
    private var wattsText: String {
        formattedAverageWatts(totals.averageWatts, placeholder: "— W")
    }
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text("^[\(totals.count) ride](inflect: true) · \(totals.minutes.formattedMinutes()) · \(wattsText) · \(totals.feet.formattedWholeNumber()) ft")
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

#Preview("Section header") {
    let container = PreviewSupport.container()
    let workouts = PreviewSupport.workouts(in: container)
    List {
        Section {
            EmptyView()
        } header: {
            SectionHeader(
                title: "Week of Oct 12",
                totals: Totals(workouts),
                showsDisclosure: true
            )
        }
    }
    .modelContainer(container)
}
