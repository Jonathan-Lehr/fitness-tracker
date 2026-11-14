#if DEBUG
import Foundation
import SwiftData

/// In-memory SwiftData fixtures for `#Preview`s. Each call gets a fresh container
/// so one preview's edits don't leak into another.
@MainActor
enum PreviewSupport {
    static func container() -> ModelContainer {
        let schema = Schema([Program.self, Workout.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            SeedData.insertRealWorkouts(container.mainContext)
            return container
        } catch {
            fatalError("Could not create preview container: \(error)")
        }
    }

    static func workouts(in container: ModelContainer) -> [Workout] {
        let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date)])
        return (try? container.mainContext.fetch(descriptor)) ?? []
    }

    static func sampleWorkout(in container: ModelContainer) -> Workout {
        guard let workout = workouts(in: container).first else {
            fatalError("Preview container has no workouts")
        }
        return workout
    }
}
#endif
