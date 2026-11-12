import XCTest
@testable import FitnessTracker

final class WorkoutDraftTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_761_000_000)

    func testManualEntryMatchesTheFormDefaults() {
        let draft = WorkoutDraft.manualEntry
        XCTAssertEqual(draft.title, "")
        XCTAssertEqual(draft.durationMinutes, 45)
        XCTAssertEqual(draft.distanceMiles, 10)
        XCTAssertEqual(draft.calories, 350)
        XCTAssertEqual(draft.elevationFeet, 1000)
        XCTAssertEqual(draft.avgRPM, 75)
        XCTAssertEqual(draft.avgWatts, 85)
        XCTAssertEqual(draft.inclineAvg, 2)
        XCTAssertEqual(draft.inclineMax, 10)
        XCTAssertEqual(draft.resistanceAvg, 10)
        XCTAssertEqual(draft.resistanceMax, 15)
        XCTAssertEqual(draft.notes, "")
        XCTAssertNil(draft.photoData)
    }

    func testDefaultDraftHasZeroStats() {
        let draft = WorkoutDraft()
        XCTAssertEqual(draft.durationMinutes, 0)
        XCTAssertEqual(draft.distanceMiles, 0)
        XCTAssertEqual(draft.calories, 0)
        XCTAssertEqual(draft.elevationFeet, 0)
        XCTAssertEqual(draft.avgRPM, 0)
        XCTAssertEqual(draft.avgWatts, 0)
        XCTAssertEqual(draft.inclineAvg, 0)
        XCTAssertEqual(draft.inclineMax, 0)
        XCTAssertEqual(draft.resistanceAvg, 0)
        XCTAssertEqual(draft.resistanceMax, 0)
    }

    func testInitFromSummaryCopiesValuesAndUsesZeroForMissingFields() {
        var summary = IFitSummary()
        summary.title = "Hurrah Pass Endurance Ride"
        summary.date = date
        summary.durationMinutes = 65
        summary.distanceMiles = 13.88
        summary.calories = 499
        summary.avgWatts = 85
        // duration/distance/calories/watts/title/date present; the rest missing
        let photo = Data([1, 2, 3])
        let draft = WorkoutDraft(summary: summary, photoData: photo)
        XCTAssertEqual(draft.title, "Hurrah Pass Endurance Ride")
        XCTAssertEqual(draft.date, date)
        XCTAssertEqual(draft.durationMinutes, 65)
        XCTAssertEqual(draft.distanceMiles, 13.88)
        XCTAssertEqual(draft.calories, 499)
        XCTAssertEqual(draft.elevationFeet, 0)
        XCTAssertEqual(draft.avgRPM, 0)
        XCTAssertEqual(draft.avgWatts, 85)
        XCTAssertEqual(draft.inclineAvg, 0)
        XCTAssertEqual(draft.inclineMax, 0)
        XCTAssertEqual(draft.resistanceAvg, 0)
        XCTAssertEqual(draft.resistanceMax, 0)
        XCTAssertEqual(draft.notes, "")
        XCTAssertEqual(draft.photoData, photo)
    }

    func testInitFromSummaryWithNoDateUsesNow() {
        let draft = WorkoutDraft(summary: IFitSummary())
        XCTAssertEqual(draft.title, "")
        XCTAssertEqual(draft.date.timeIntervalSinceNow, 0, accuracy: 1)
    }

    func testInitFromWorkoutCopiesFieldsIncludingNotesAndPhoto() {
        let photo = Data([9])
        let workout = Workout(
            date: date,
            program: Program(title: "Green River Recovery Ride"),
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
        workout.photoData = photo
        let draft = WorkoutDraft(workout: workout)
        XCTAssertEqual(draft.title, "Green River Recovery Ride")
        XCTAssertEqual(draft.date, date)
        XCTAssertEqual(draft.durationMinutes, 42)
        XCTAssertEqual(draft.distanceMiles, 10.02)
        XCTAssertEqual(draft.calories, 310)
        XCTAssertEqual(draft.elevationFeet, 599)
        XCTAssertEqual(draft.avgRPM, 79)
        XCTAssertEqual(draft.avgWatts, 79)
        XCTAssertEqual(draft.inclineAvg, 1)
        XCTAssertEqual(draft.inclineMax, 9)
        XCTAssertEqual(draft.resistanceAvg, 11)
        XCTAssertEqual(draft.resistanceMax, 16)
        XCTAssertEqual(draft.notes, "Felt good")
        XCTAssertEqual(draft.photoData, photo)
    }

    func testInitFromWorkoutTreatsNilNotesAsEmpty() {
        let workout = Workout(date: date, program: nil)
        XCTAssertNil(workout.notes)
        XCTAssertEqual(WorkoutDraft(workout: workout).notes, "")
    }

    func testApplyWritesStatsAndTurnsEmptyNotesIntoNil() {
        let workout = Workout(date: date, program: nil, notes: "old")
        var draft = WorkoutDraft(workout: workout)
        draft.date = date.addingTimeInterval(60)
        draft.durationMinutes = 48
        draft.distanceMiles = 9.85
        draft.calories = 376
        draft.elevationFeet = 1542
        draft.avgRPM = 75
        draft.avgWatts = 88
        draft.inclineAvg = 3.6
        draft.inclineMax = 10
        draft.resistanceAvg = 8
        draft.resistanceMax = 15
        draft.notes = ""
        draft.apply(to: workout)
        XCTAssertEqual(workout.date, date.addingTimeInterval(60))
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
        XCTAssertNil(workout.notes)
    }

    func testApplyKeepsNonEmptyNotes() {
        let workout = Workout(date: date, program: nil)
        var draft = WorkoutDraft(workout: workout)
        draft.notes = "Hard climb"
        draft.apply(to: workout)
        XCTAssertEqual(workout.notes, "Hard climb")
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
        XCTAssertEqual(workout.date, date)
        XCTAssertNil(workout.program)
    }
}
