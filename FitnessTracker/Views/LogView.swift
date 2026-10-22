import SwiftUI
import SwiftData

struct LogFilter: Equatable {
    var useDateRange = false
    var startDate = Calendar.current.date(byAdding: .month, value: -3, to: .now) ?? .now
    var endDate = Date.now
    var programTitle: String? = nil
    var type: WorkoutType? = nil
    var minWatts = 0

    var isActive: Bool { useDateRange || programTitle != nil || type != nil || minWatts > 0 }

    func matches(_ w: Workout) -> Bool {
        if useDateRange {
            let cal = Calendar.current
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

    private var filtered: [Workout] { workouts.filter(filter.matches) }

    private var sections: [(start: Date, workouts: [Workout])] {
        let grouped = Dictionary(grouping: filtered) { period.start(of: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            List {
                PeriodSummaryCard(period: $period,
                                  summary: PeriodSummary.compute(filtered, period: period),
                                  filtered: filter.isActive)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .animation(.default, value: period)

                if sections.isEmpty {
                    ContentUnavailableView("No Rides", systemImage: "bicycle",
                                           description: Text(filter.isActive ? "No rides match the filters." : "Add a ride to get started."))
                }
                ForEach(sections, id: \.start) { section in
                    Section {
                        ForEach(section.workouts) { w in
                            NavigationLink(value: w) { WorkoutRow(workout: w) }
                        }
                        .onDelete { offsets in
                            for i in offsets { context.delete(section.workouts[i]) }
                        }
                    } header: {
                        SectionHeader(title: period.label(for: section.start), totals: Totals(section.workouts))
                    }
                }
            }
            .navigationTitle("Rides")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Label("Add Ride", systemImage: "plus") }
                }
                ToolbarItem {
                    Button { showFilters = true } label: {
                        Label("Filters", systemImage: filter.isActive
                              ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
                #if DEBUG
                ToolbarItem {
                    Button { showDebug = true } label: { Label("Debug", systemImage: "ladybug") }
                }
                #endif
            }
            .sheet(isPresented: $showAdd) { AddRideView() }
            .sheet(isPresented: $showFilters) { FilterView(filter: $filter) }
            #if DEBUG
            .sheet(isPresented: $showDebug) { DebugMenuView() }
            #endif
        }
    }
}

struct SectionHeader: View {
    let title: String
    let totals: Totals
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text("\(totals.count) rides · \(totals.minutes.minutesText) · \(totals.calories) cal · \(totals.feet) ft")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(totals.miles.milesText)
                .font(.headline.bold()).monospacedDigit()
                .foregroundStyle(.primary)
        }
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
