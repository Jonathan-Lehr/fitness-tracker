import SwiftUI
import SwiftData
import Charts

enum ChartMetric: String, CaseIterable, Identifiable {
    case watts = "Watts"
    case distance = "Distance"
    case rpm = "RPM"

    var id: String { rawValue }

    func value(_ workout: Workout) -> Double {
        switch self {
        case .watts: Double(workout.avgWatts)
        case .distance: workout.distanceMiles
        case .rpm: Double(workout.avgRPM)
        }
    }

    /// Rides that recorded this metric. A zero means the value is missing, so plotting it
    /// would drag the line down to the axis.
    func recorded(in workouts: [Workout]) -> [Workout] {
        workouts.filter { value($0) > 0 }
    }

    /// The ride with the highest value for this metric; on a tie, the earliest one in
    /// `workouts`. Nil if no ride recorded the metric.
    func best(in workouts: [Workout]) -> Workout? {
        recorded(in: workouts).reduce(nil) { currentBest, workout in
            guard let currentBest, value(currentBest) >= value(workout) else { return workout }
            return currentBest
        }
    }

    /// The metric's value with its unit, e.g. "142 W", "19.14 mi", or "78 RPM".
    func formattedValue(_ workout: Workout, locale: Locale = .current) -> String {
        switch self {
        case .watts: "\(workout.avgWatts.formattedWholeNumber(locale: locale)) W"
        case .distance: workout.distanceMiles.formattedMilesWithUnit(locale: locale)
        case .rpm: "\(workout.avgRPM.formattedWholeNumber(locale: locale)) RPM"
        }
    }
}

struct ProgramDetailView: View {
    let program: Program
    @State private var metric: ChartMetric = .watts
    @State private var selected: Set<PersistentIdentifier> = []
    @State private var showCompare = false

    private var efforts: [Workout] { program.sortedWorkouts }
    private var chartedEfforts: [Workout] { metric.recorded(in: efforts) }
    private var best: Workout? { metric.best(in: efforts) }
    private var selectedPair: [Workout] {
        efforts.filter { selected.contains($0.persistentModelID) }
    }

    var body: some View {
        List {
            Section {
                effortChart
            }

            Section {
                ForEach(efforts.reversed()) { workout in
                    ProgramEffortRow(
                        workout: workout,
                        isSelected: selected.contains(workout.persistentModelID),
                        isBest: workout.persistentModelID == best?.persistentModelID,
                        onToggle: { toggle(workout) }
                    )
                }
            } header: {
                Text("\(efforts.count.formattedWholeNumber()) efforts · select two to compare")
            }
        }
        .navigationTitle(program.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Compare") { showCompare = true }.disabled(selectedPair.count != 2)
            }
        }
        .sheet(isPresented: $showCompare) {
            if selectedPair.count == 2 {
                CompareView(earlier: selectedPair[0], later: selectedPair[1])
            }
        }
    }

    private func toggle(_ workout: Workout) {
        let id = workout.persistentModelID
        if selected.contains(id) {
            selected.remove(id)
        } else {
            if selected.count >= 2, let oldest = selectedPair.first { selected.remove(oldest.persistentModelID) }
            selected.insert(id)
        }
    }

    /// Metric picker, effort chart, and the current "Best" label.
    @ViewBuilder
    private var effortChart: some View {
        Picker("Metric", selection: $metric) {
            ForEach(ChartMetric.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        Chart {
            ForEach(chartedEfforts) { workout in
                LineMark(x: .value("Date", workout.date), y: .value(metric.rawValue, metric.value(workout)))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", workout.date), y: .value(metric.rawValue, metric.value(workout)))
                    .foregroundStyle(workout.persistentModelID == best?.persistentModelID ? Color.orange : Color.blue)
                    .symbolSize(workout.persistentModelID == best?.persistentModelID ? 120 : 30)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 220)
        if let best {
            Label("Best: \(metric.formattedValue(best)) on \(best.date.formatted(date: .abbreviated, time: .omitted))",
                  systemImage: "star.fill")
                .foregroundStyle(.orange)
        }
    }
}

/// One effort in the program list: selection circle, row, and optional best-effort star.
private struct ProgramEffortRow: View {
    let workout: Workout
    let isSelected: Bool
    let isBest: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.borderless)
            NavigationLink(value: workout) {
                HStack {
                    WorkoutRow(workout: workout, showYear: true)
                    if isBest {
                        Image(systemName: "star.fill").foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}
