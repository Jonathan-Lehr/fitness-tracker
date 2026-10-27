import SwiftUI
import SwiftData
import CoreData
import Combine

enum AppEnvironment {
    static let cloudKitContainerID = "iCloud.com.jonathanlehr.FitnessTracker"

    /// True under XCTest or SwiftUI previews: use an in-memory store with no CloudKit,
    /// so unsigned CI builds (no iCloud entitlement) still work.
    static var isTestOrPreview: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil
            || env["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || NSClassFromString("XCTestCase") != nil
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([Program.self, Workout.self])
        let config: ModelConfiguration
        if isTestOrPreview {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            config = ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudKitContainerID))
        }
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}

@main
struct FitnessTrackerApp: App {
    let container = AppEnvironment.makeContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Monday-first weeks for DatePickers and Swift Charts' week units.
                .environment(\.calendar, .app)
                .onAppear {
                    let context = container.mainContext
                    SeedData.seedIfNeeded(context)
                    DataDeduper.run(context)
                }
                // CloudKit imports arrive as remote store changes; dedupe after each burst.
                .onReceive(NotificationCenter.default
                    .publisher(for: .NSPersistentStoreRemoteChange)
                    .debounce(for: .seconds(2), scheduler: RunLoop.main)) { _ in
                    DataDeduper.run(container.mainContext)
                }
        }
        .modelContainer(container)
        #if os(macOS)
        // First launch / new windows only (macOS restores saved window frames): as narrow as the
        // summary card's 3-column layout allows, ~80% of the main screen's visible height.
        .defaultSize(WindowSizing.defaultSizeOnMainScreen)
        .windowResizability(.contentMinSize)
        #endif
    }
}
