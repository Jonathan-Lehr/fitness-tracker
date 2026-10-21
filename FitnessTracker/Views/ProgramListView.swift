import SwiftUI
import SwiftData

struct ProgramListView: View {
    @Query(sort: \Program.title) private var programs: [Program]

    var body: some View {
        NavigationStack {
            List(programs.filter { !($0.workouts ?? []).isEmpty }) { p in
                NavigationLink(value: p) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(p.title).font(.body.weight(.semibold))
                            Text(p.type.label).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(p.workouts?.count ?? 0)×").monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Programs")
            .navigationDestination(for: Program.self) { ProgramDetailView(program: $0) }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
        }
    }
}
