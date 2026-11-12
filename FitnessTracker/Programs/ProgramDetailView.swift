import SwiftUI
import SwiftData
import Charts

enum ChartMetric: String, CaseIterable, Identifiable {
    case watts = "Watts"
    case duration = "Duration"
    case calories = "Calories"

    var id: String { rawValue }
    func value(_ workout: Workout) -> Double {
        switch self {
        case .watts: Double(workout.avgWatts)
        case .duration: workout.durationMinutes
        case .calories: Double(workout.calories)
        }
    }
}

struct ProgramDetailView: View {
    let program: Program
    @State private var metric: ChartMetric = .watts
    @State private var selected: Set<PersistentIdentifier> = []
    @State private var showCompare = false

    private var efforts: [Workout] { program.sortedWorkouts }
    private var best: Workout? { efforts.max { $0.avgWatts < $1.avgWatts } }
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
                CompareView(a: selectedPair[0], b: selectedPair[1])
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
            ForEach(efforts) { workout in
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
            Label("Best: \(best.avgWatts.formattedWholeNumber()) W on \(best.date.formatted(date: .abbreviated, time: .omitted))",
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
