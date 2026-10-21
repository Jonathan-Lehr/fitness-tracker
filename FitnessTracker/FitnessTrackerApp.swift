import SwiftUI
import SwiftData

@main
struct FitnessTrackerApp: App {
    let container: ModelContainer = {
        let schema = Schema([Program.self, Workout.self])
        // CloudKit sync can be enabled later by adding the iCloud capability and
        // passing cloudKitDatabase: .automatic. Models are already CloudKit-compatible.
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { SeedData.seedIfNeeded(container.mainContext) }
        }
        .modelContainer(container)
    }
}
