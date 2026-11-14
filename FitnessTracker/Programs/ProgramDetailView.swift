import SwiftUI
import SwiftData
import Charts

enum ChartMetric: String, CaseIterable, Identifiable {
    case distance = "Distance"
    case watts = "Watts"
    case rpm = "RPM"

    var id: String { rawValue }

    func value(_ workout: Workout) -> Double {
        switch self {
        case .distance: workout.distanceMiles
        case .watts: Double(workout.avgWatts)
        case .rpm: Double(workout.avgRPM)
        }
    }

    /// Workouts that recorded this metric. A zero means the value is missing, so plotting it
    /// would drag the line down to the axis.
    func recorded(in workouts: [Workout]) -> [Workout] {
        workouts.filter { value($0) > 0 }
    }

    /// The workout with the highest value for this metric; on a tie, the earliest one in
    /// `workouts`. Nil if no workout recorded the metric.
    func best(in workouts: [Workout]) -> Workout? {
        recorded(in: workouts).reduce(nil) { currentBest, workout in
            guard let currentBest, value(currentBest) >= value(workout) else { return workout }
            return currentBest
        }
    }

    /// The metric's value with its unit, e.g. "142 W", "19.14 mi", or "78 RPM".
    func formattedValue(_ workout: Workout, locale: Locale = .current) -> String {
        switch self {
        case .distance: workout.distanceMiles.formattedMilesWithUnit(locale: locale)
        case .watts: "\(workout.avgWatts.formattedWholeNumber(locale: locale)) W"
        case .rpm: "\(workout.avgRPM.formattedWholeNumber(locale: locale)) RPM"
        }
    }
}

struct ProgramDetailView: View {
    let program: Program
    @State private var metric: ChartMetric = .distance
    @State private var selected: Set<PersistentIdentifier> = []
    @State private var showCompare = false

    private var efforts: [Workout] { program.sortedWorkouts }
    private var chartedEfforts: [Workout] { metric.recorded(in: efforts) }
    private var best: Workout? { metric.best(in: efforts) }
    private var selectedPair: [Workout] {
        efforts.filter { selected.contains($0.persistentModelID) }
    }
    /// Comparing needs two efforts, so with fewer the selection circles, header prompt,
    /// and Compare button are hidden.
    private var canCompare: Bool { efforts.count >= 2 }

    /// With this many charted workouts or fewer, the x-axis labels each workout's date; with more,
    /// Charts picks evenly spaced dates so the labels don't collide.
    private static let maxWorkoutDateLabels = 6

    /// Workout dates as x-axis values when there are few enough to label; nil for automatic.
    private var workoutDateAxisValues: [Date]? {
        chartedEfforts.count <= Self.maxWorkoutDateLabels ? chartedEfforts.map(\.date) : nil
    }

    /// Month and day, plus the year when the charted workouts span more than one year.
    private var axisDateFormat: Date.FormatStyle {
        let years = Set(chartedEfforts.map { Calendar.app.component(.year, from: $0.date) })
        let monthDay = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return years.count > 1 ? monthDay.year(.twoDigits) : monthDay
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
                        onToggle: canCompare ? { toggle(workout) } : nil
                    )
                }
            } header: {
                if canCompare {
                    Text("\(efforts.count.formattedWholeNumber()) efforts · select two to compare")
                }
            } footer: {
                if !canCompare {
                    Text("Log another workout of this program to see your trend and compare efforts.")
                        .padding(.top, 12)
                }
            }
        }
        .navigationTitle(program.title)
        .toolbar {
            if canCompare {
                ToolbarItem(placement: .primaryAction) {
                    Button("Compare") { showCompare = true }.disabled(selectedPair.count != 2)
                }
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

    /// Metric picker and effort chart in one row, then the current "Best" label.
    @ViewBuilder
    private var effortChart: some View {
        VStack(spacing: 16) {
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
            // Padding keeps the first and last points off the plot edges and leaves room
            // for their date labels, which would otherwise be clipped ("N…").
            .chartXScale(range: .plotDimension(padding: 28))
            .chartXAxis {
                if let workoutDateAxisValues {
                    AxisMarks(values: workoutDateAxisValues) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: axisDateFormat)
                    }
                } else {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: axisDateFormat)
                    }
                }
            }
            .frame(height: 220)
        }
        .padding(.vertical, 4)
        .animation(.smooth, value: metric)
        if let best {
            Label("Best: \(metric.formattedValue(best)) on \(best.date.formatted(date: .abbreviated, time: .omitted))",
                  systemImage: "star.fill")
                .foregroundStyle(.orange)
                .contentTransition(.numericText())
                .animation(.smooth, value: metric)
        }
    }
}

/// One effort in the program list: selection circle, row, and optional best-effort star.
private struct ProgramEffortRow: View {
    let workout: Workout
    let isSelected: Bool
    let isBest: Bool
    /// Toggles selection for comparing; nil hides the selection circle.
    let onToggle: (() -> Void)?

    var body: some View {
        HStack {
            if let onToggle {
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.borderless)
            }
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
