import XCTest
import SwiftData
@testable import FitnessTracker

@MainActor
final class DataMaintenanceTests: XCTestCase {
    func testDeleteAllRemovesWorkoutsAndPrograms() throws {
        let context = try TestSupport.inMemoryContext()
        SeedData.insertRealRides(context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Workout>()).count, 4)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Program>()).count, 4)

        DataMaintenance.deleteAll(context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Workout>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Program>()).count, 0)
    }

    func testDeleteAllSimulatedOnlyLeavesRealRides() throws {
        let context = try TestSupport.inMemoryContext()
        SeedData.insertRealRides(context)
        let realProgram = Program.findOrCreate(title: "Green River Recovery Ride", in: context)
        let simulatedOnlyProgram = Program(title: "Fake Climb")
        context.insert(simulatedOnlyProgram)
        context.insert(TestSupport.ride(
            date: Date(timeIntervalSince1970: 1_770_000_000),
            program: realProgram,
            isSimulated: true
        ))
        context.insert(TestSupport.ride(
            date: Date(timeIntervalSince1970: 1_770_100_000),
            program: simulatedOnlyProgram,
            isSimulated: true
        ))
        try context.save()

        DataMaintenance.deleteAll(context, simulatedOnly: true)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(workouts.count, 4)
        XCTAssertTrue(workouts.allSatisfy { !$0.isSimulated })
        let programs = try context.fetch(FetchDescriptor<Program>())
        XCTAssertEqual(programs.count, 4)
        XCTAssertNil(programs.first { $0.title == "Fake Climb" })
        XCTAssertNotNil(programs.first { $0.title == "Green River Recovery Ride" })
    }
}
