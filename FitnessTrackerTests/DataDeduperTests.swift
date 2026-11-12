import XCTest
import SwiftData
@testable import FitnessTracker

@MainActor
final class DataDeduperTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        try TestSupport.inMemoryContext()
    }

    func testSeedTwiceThenDedupeLeavesFourRides() throws {
        let context = try makeContext()
        // Simulates two devices each seeding before sync, then merging.
        SeedData.insertRealRides(context)
        let date = Date(timeIntervalSince1970: 1_760_000_000)
        for _ in 0..<2 {
            let p = Program(title: "Green River Recovery Ride")
            context.insert(p)
            context.insert(TestSupport.ride(
                date: date,
                program: p,
                durationMinutes: 1,
                distanceMiles: 1,
                calories: 1,
                elevationFeet: 1,
                avgRPM: 1,
                avgWatts: 1,
                resistanceAvg: 1,
                resistanceMax: 1
            ))
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

    func testKeepsProgramWithMoreRidesAndReassignsWorkouts() throws {
        let context = try makeContext()
        let keeper = Program(title: "Hill Climb")
        let duplicate = Program(title: "hill climb")
        context.insert(keeper)
        context.insert(duplicate)
        let firstDate = Date(timeIntervalSinceReferenceDate: 60 * 10_000)
        let secondDate = Date(timeIntervalSinceReferenceDate: 60 * 10_001)
        let thirdDate = Date(timeIntervalSinceReferenceDate: 60 * 10_002)
        context.insert(TestSupport.ride(date: firstDate, program: keeper))
        context.insert(TestSupport.ride(date: secondDate, program: keeper))
        context.insert(TestSupport.ride(date: thirdDate, program: duplicate))
        try context.save()

        DataDeduper.run(context)

        let programs = try context.fetch(FetchDescriptor<Program>())
        XCTAssertEqual(programs.count, 1)
        XCTAssertTrue(programs[0] === keeper)
        XCTAssertEqual(keeper.title, "Hill Climb")
        XCTAssertEqual(keeper.workouts?.count, 3)
    }

    func testKeepsWorkoutWithPhotoOverOneWithOnlyNotes() throws {
        let context = try makeContext()
        let (withPhoto, _) = try insertDuplicatePair(
            into: context,
            configureFirst: { workout in
                workout.photoData = Data([1, 2, 3])
            },
            configureSecond: { workout in
                workout.notes = "Felt strong"
            }
        )

        DataDeduper.run(context)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(workouts.count, 1)
        XCTAssertTrue(workouts[0] === withPhoto)
        XCTAssertEqual(workouts[0].photoData, Data([1, 2, 3]))
        XCTAssertNil(workouts[0].notes)
    }

    func testKeepsWorkoutWithPhotoAndNotesOverPhotoOnly() throws {
        let context = try makeContext()
        let (richer, _) = try insertDuplicatePair(
            into: context,
            configureFirst: { workout in
                workout.photoData = Data([1])
                workout.notes = "Felt strong"
            },
            configureSecond: { workout in
                workout.photoData = Data([2])
            }
        )

        DataDeduper.run(context)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(workouts.count, 1)
        XCTAssertTrue(workouts[0] === richer)
        XCTAssertEqual(workouts[0].notes, "Felt strong")
        XCTAssertEqual(workouts[0].photoData, Data([1]))
    }

    func testKeepsWorkoutWithNotesOverEmptyNotes() throws {
        let context = try makeContext()
        let (withNotes, _) = try insertDuplicatePair(
            into: context,
            configureFirst: { workout in
                workout.notes = "Felt strong"
            },
            configureSecond: { workout in
                workout.notes = ""
            }
        )

        DataDeduper.run(context)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(workouts.count, 1)
        XCTAssertTrue(workouts[0] === withNotes)
        XCTAssertEqual(workouts[0].notes, "Felt strong")
    }

    func testDoesNotMergeWorkoutsInDifferentMinutes() throws {
        let context = try makeContext()
        let program = Program.findOrCreate(title: "Hill Climb", in: context)
        let firstDate = Date(timeIntervalSinceReferenceDate: 60 * 10_000)
        let nextMinute = Date(timeIntervalSinceReferenceDate: 60 * 10_000 + 60)
        context.insert(TestSupport.ride(date: firstDate, program: program))
        context.insert(TestSupport.ride(date: nextMinute, program: program))
        try context.save()

        DataDeduper.run(context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Workout>()).count, 2)
    }

    /// Two rides on the same program in the same start minute, with optional per-ride extras.
    private func insertDuplicatePair(
        into context: ModelContext,
        configureFirst: (Workout) -> Void,
        configureSecond: (Workout) -> Void
    ) throws -> (Workout, Workout) {
        let program = Program.findOrCreate(title: "Hill Climb", in: context)
        let firstDate = Date(timeIntervalSinceReferenceDate: 60 * 10_000)
        let sameMinute = Date(timeIntervalSinceReferenceDate: 60 * 10_000 + 30)
        let firstWorkout = TestSupport.ride(date: firstDate, program: program)
        configureFirst(firstWorkout)
        context.insert(firstWorkout)
        let secondWorkout = TestSupport.ride(date: sameMinute, program: program)
        configureSecond(secondWorkout)
        context.insert(secondWorkout)
        try context.save()
        return (firstWorkout, secondWorkout)
    }
}
