import SwiftUI
import SwiftData

struct ProgramListView: View {
    @Query(sort: \Program.title) private var programs: [Program]

    var body: some View {
        NavigationStack {
            List(programs.filter { !($0.workouts ?? []).isEmpty }) { program in
                NavigationLink(value: program) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(program.title).font(.body.weight(.semibold))
                            Text(program.type.label).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\((program.workouts?.count ?? 0).formattedWholeNumber())×").monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Programs")
            .navigationDestination(for: Program.self) { ProgramDetailView(program: $0) }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
        }
    }
}
