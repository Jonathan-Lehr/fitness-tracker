import SwiftUI
import SwiftData
import Charts

enum ChartMetric: String, CaseIterable, Identifiable {
    case watts = "Watts", duration = "Duration", calories = "Calories"
    var id: String { rawValue }
    func value(_ w: Workout) -> Double {
        switch self {
        case .watts: Double(w.avgWatts)
        case .duration: w.durationMinutes
        case .calories: Double(w.calories)
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
                Picker("Metric", selection: $metric) {
                    ForEach(ChartMetric.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Chart {
                    ForEach(efforts) { w in
                        LineMark(x: .value("Date", w.date), y: .value(metric.rawValue, metric.value(w)))
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", w.date), y: .value(metric.rawValue, metric.value(w)))
                            .foregroundStyle(w.persistentModelID == best?.persistentModelID ? Color.orange : Color.blue)
                            .symbolSize(w.persistentModelID == best?.persistentModelID ? 120 : 30)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 220)
                if let best {
                    Label("Best: \(best.avgWatts) W on \(best.date.formatted(date: .abbreviated, time: .omitted))",
                          systemImage: "star.fill")
                        .foregroundStyle(.orange)
                }
            }

            Section {
                ForEach(efforts.reversed()) { w in
                    HStack {
                        Button { toggle(w) } label: {
                            Image(systemName: selected.contains(w.persistentModelID) ? "checkmark.circle.fill" : "circle")
                        }
                        .buttonStyle(.borderless)
                        NavigationLink(value: w) {
                            HStack {
                                WorkoutRow(workout: w)
                                if w.persistentModelID == best?.persistentModelID {
                                    Image(systemName: "star.fill").foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("\(efforts.count) efforts · select two to compare")
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

    private func toggle(_ w: Workout) {
        let id = w.persistentModelID
        if selected.contains(id) {
            selected.remove(id)
        } else {
            if selected.count >= 2, let oldest = selectedPair.first { selected.remove(oldest.persistentModelID) }
            selected.insert(id)
        }
    }
}
