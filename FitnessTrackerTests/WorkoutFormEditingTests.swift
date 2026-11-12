import XCTest
import SwiftData
@testable import FitnessTracker

@MainActor
final class WorkoutFormEditingTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_761_000_000)

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Program.self, Workout.self])
        return try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        ])
    }

    private func makeContext(_ container: ModelContainer) -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func workoutCount(_ context: ModelContext) throws -> Int {
        try context.fetch(FetchDescriptor<Workout>()).count
    }

    private func insertSampleRide(into context: ModelContext) throws -> Workout {
        let program = Program.findOrCreate(title: "Green River Recovery Ride", in: context)
        let workout = Workout(
            date: date,
            program: program,
            durationMinutes: 42,
            distanceMiles: 10.02,
            calories: 310,
            elevationFeet: 599,
            avgRPM: 79,
            avgWatts: 79,
            inclineAvg: 1,
            inclineMax: 9,
            resistanceAvg: 11,
            resistanceMax: 16,
            notes: "Felt good"
        )
        context.insert(workout)
        try context.save()
        return workout
    }

    func testNewRideIsNotPersistedUntilSave() throws {
        let container = try makeContainer()
        let editing = WorkoutFormEditing.manualEntry(date: date, container: container)
        editing.workout.durationMinutes = 48
        editing.title = "Mineral Bottom Endurance Ride"
        XCTAssertFalse(editing.isEditingExisting)
        let freshContext = ModelContext(container)
        XCTAssertEqual(try workoutCount(freshContext), 0)
    }

    func testSaveInsertsNewRideWithEnteredValues() throws {
        let container = try makeContainer()
        let editing = WorkoutFormEditing.manualEntry(date: date, container: container)
        editing.title = "Mineral Bottom Endurance Ride"
        editing.workout.durationMinutes = 48
        editing.workout.distanceMiles = 9.85
        editing.workout.calories = 376
        editing.workout.elevationFeet = 1542
        editing.workout.avgRPM = 75
        editing.workout.avgWatts = 88
        editing.workout.inclineAvg = 3.6
        editing.workout.inclineMax = 10
        editing.workout.resistanceAvg = 8
        editing.workout.resistanceMax = 15
        editing.workout.notes = "Hard climb"
        XCTAssertEqual(try workoutCount(ModelContext(container)), 0)

        try editing.save()

        let rides = try ModelContext(container).fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(rides.count, 1)
        let workout = try XCTUnwrap(rides.first)
        XCTAssertEqual(workout.title, "Mineral Bottom Endurance Ride")
        XCTAssertEqual(workout.date, date)
        XCTAssertEqual(workout.durationMinutes, 48)
        XCTAssertEqual(workout.distanceMiles, 9.85)
        XCTAssertEqual(workout.calories, 376)
        XCTAssertEqual(workout.elevationFeet, 1542)
        XCTAssertEqual(workout.avgRPM, 75)
        XCTAssertEqual(workout.avgWatts, 88)
        XCTAssertEqual(workout.inclineAvg, 3.6)
        XCTAssertEqual(workout.inclineMax, 10)
        XCTAssertEqual(workout.resistanceAvg, 8)
        XCTAssertEqual(workout.resistanceMax, 15)
        XCTAssertEqual(workout.notes, "Hard climb")
    }

    func testEditCancelDoesNotLeakIntoMainContext() throws {
        let container = try makeContainer()
        let context = makeContext(container)
        let workout = try insertSampleRide(into: context)
        do {
            let editing = try WorkoutFormEditing.editing(workout, container: container)
            editing.workout.durationMinutes = 99
            editing.workout.notes = "changed"
            editing.title = "Other Ride"
            XCTAssertEqual(workout.durationMinutes, 42, "edits in the scratch context must not leak")
            XCTAssertEqual(workout.notes, "Felt good")
            XCTAssertEqual(workout.title, "Green River Recovery Ride")
        }
        // Session (and its unsaved scratch context) dropped, as Cancel does.

        XCTAssertEqual(workout.durationMinutes, 42)
        XCTAssertEqual(workout.notes, "Felt good")
        XCTAssertEqual(workout.title, "Green River Recovery Ride")
        let freshContext = ModelContext(container)
        let refetchedWorkout = try XCTUnwrap(try freshContext.fetch(FetchDescriptor<Workout>()).first)
        XCTAssertEqual(refetchedWorkout.durationMinutes, 42)
        XCTAssertEqual(refetchedWorkout.notes, "Felt good")
        XCTAssertEqual(refetchedWorkout.title, "Green River Recovery Ride")
    }

    func testEditSavePersistsChanges() throws {
        let container = try makeContainer()
        let context = makeContext(container)
        let workout = try insertSampleRide(into: context)
        let editing = try WorkoutFormEditing.editing(workout, container: container)

        editing.workout.durationMinutes = 50
        editing.workout.notes = "Updated"
        editing.title = "Green River Recovery Ride"
        try editing.save()

        // A new context on the same container should see the saved values.
        let freshContext = ModelContext(container)
        let refetchedWorkout = try XCTUnwrap(try freshContext.fetch(FetchDescriptor<Workout>()).first)
        XCTAssertEqual(refetchedWorkout.durationMinutes, 50)
        XCTAssertEqual(refetchedWorkout.notes, "Updated")
        XCTAssertEqual(refetchedWorkout.title, "Green River Recovery Ride")
        XCTAssertEqual(try workoutCount(freshContext), 1)
    }

    func testParserPrefillPopulatesWorkoutWithoutPersisting() throws {
        var summary = IFitSummary()
        summary.title = "Hurrah Pass Endurance Ride"
        summary.date = date
        summary.durationMinutes = 65
        summary.distanceMiles = 13.88
        summary.calories = 499
        summary.avgWatts = 85
        let photo = Data([1, 2, 3])
        let analysis = ThumbnailFocusAnalysis(focus: CGRect(x: 0.5, y: 0.1, width: 0.2, height: 0.25))

        let container = try makeContainer()
        let editing = WorkoutFormEditing.prefilled(
            summary: summary, photo: photo, analysis: analysis, container: container
        )

        XCTAssertEqual(try workoutCount(ModelContext(container)), 0)
        XCTAssertFalse(editing.isEditingExisting)
        XCTAssertEqual(editing.title, "Hurrah Pass Endurance Ride")
        XCTAssertEqual(editing.workout.date, date)
        XCTAssertEqual(editing.workout.durationMinutes, 65)
        XCTAssertEqual(editing.workout.distanceMiles, 13.88)
        XCTAssertEqual(editing.workout.calories, 499)
        XCTAssertEqual(editing.workout.elevationFeet, 0)
        XCTAssertEqual(editing.workout.avgRPM, 0)
        XCTAssertEqual(editing.workout.avgWatts, 85)
        XCTAssertEqual(editing.workout.inclineAvg, 0)
        XCTAssertEqual(editing.workout.photoData, photo)
        XCTAssertEqual(editing.workout.thumbnailFocus, analysis.focus)
    }

    func testParserPrefillSaveInsertsValues() throws {
        var summary = IFitSummary()
        summary.title = "Hurrah Pass Endurance Ride"
        summary.date = date
        summary.durationMinutes = 65
        summary.avgWatts = 85
        let container = try makeContainer()
        let editing = WorkoutFormEditing.prefilled(summary: summary, container: container)
        XCTAssertEqual(try workoutCount(ModelContext(container)), 0)
        try editing.save()

        let workout = try XCTUnwrap(try ModelContext(container).fetch(FetchDescriptor<Workout>()).first)
        XCTAssertEqual(workout.title, "Hurrah Pass Endurance Ride")
        XCTAssertEqual(workout.durationMinutes, 65)
        XCTAssertEqual(workout.avgWatts, 85)
        XCTAssertEqual(workout.elevationFeet, 0)
    }

    func testManualEntryDefaults() {
        let workout = Workout(forManualEntry: date)
        XCTAssertEqual(workout.date, date)
        XCTAssertNil(workout.program)
        XCTAssertEqual(workout.durationMinutes, 45)
        XCTAssertEqual(workout.distanceMiles, 10)
        XCTAssertEqual(workout.calories, 350)
        XCTAssertEqual(workout.elevationFeet, 1000)
        XCTAssertEqual(workout.avgRPM, 75)
        XCTAssertEqual(workout.avgWatts, 85)
        XCTAssertEqual(workout.inclineAvg, 2)
        XCTAssertEqual(workout.inclineMax, 10)
        XCTAssertEqual(workout.resistanceAvg, 10)
        XCTAssertEqual(workout.resistanceMax, 15)
    }

    func testWorkoutInitDefaultsStatsToZero() {
        let workout = Workout(date: date, program: nil)
        XCTAssertEqual(workout.durationMinutes, 0)
        XCTAssertEqual(workout.distanceMiles, 0)
        XCTAssertEqual(workout.calories, 0)
        XCTAssertEqual(workout.elevationFeet, 0)
        XCTAssertEqual(workout.avgRPM, 0)
        XCTAssertEqual(workout.avgWatts, 0)
        XCTAssertEqual(workout.inclineAvg, 0)
        XCTAssertEqual(workout.inclineMax, 0)
        XCTAssertEqual(workout.resistanceAvg, 0)
        XCTAssertEqual(workout.resistanceMax, 0)
        XCTAssertNil(workout.notes)
        XCTAssertFalse(workout.isSimulated)
    }
}
