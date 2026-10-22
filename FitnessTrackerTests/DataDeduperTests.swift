import XCTest
import SwiftData
@testable import FitnessTracker

@MainActor
final class DataDeduperTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let schema = Schema([Program.self, Workout.self])
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        ])
        return ModelContext(container)
    }

    func testSeedTwiceThenDedupeLeavesFourRides() throws {
        let context = try makeContext()
        // Simulates two devices each seeding before sync, then merging.
        SeedData.insertRealRides(context)
        let date = Date(timeIntervalSince1970: 1_760_000_000)
        for _ in 0..<2 {
            let p = Program(title: "Green River Recovery Ride")
            context.insert(p)
            context.insert(Workout(date: date, program: p, durationMinutes: 1, distanceMiles: 1, calories: 1,
                                   elevationFeet: 1, avgRPM: 1, avgWatts: 1, inclineAvg: 0, inclineMax: 0,
                                   resistanceAvg: 1, resistanceMax: 1))
        }
        try context.save()
        DataDeduper.run(context)

        let programs = try context.fetch(FetchDescriptor<Program>())
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(programs.count, 4)
        XCTAssertEqual(workouts.count, 5) // 4 real + 1 deduped extra
        XCTAssertEqual(programs.first { $0.title == "Green River Recovery Ride" }?.workouts?.count, 2)
    }

    func testInsertRealRidesSkipsExisting() throws {
        let context = try makeContext()
        SeedData.insertRealRides(context)
        SeedData.insertRealRides(context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Workout>()).count, 4)
    }
}
