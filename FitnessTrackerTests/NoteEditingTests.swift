import XCTest
import SwiftData
@testable import FitnessTracker

@MainActor
final class NoteEditingTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_761_000_000)

    private func makeContainer() throws -> ModelContainer {
        try TestSupport.inMemoryContainer()
    }

    private func makeContext(_ container: ModelContainer) -> ModelContext {
        TestSupport.context(on: container, autosaveEnabled: false)
    }

    private func insertRide(into context: ModelContext, notes: String? = nil) throws -> Workout {
        let program = Program.findOrCreate(title: "Green River Recovery Ride", in: context)
        let workout = TestSupport.ride(date: date, program: program, notes: notes)
        context.insert(workout)
        try context.save()
        return workout
    }

    func testNoteIsNotPersistedUntilSave() throws {
        let container = try makeContainer()
        let context = makeContext(container)
        let workout = try insertRide(into: context)
        let editing = try NoteEditing.editing(workout, container: container)
        editing.notesText = "Felt strong on the climb"

        XCTAssertTrue(editing.canSave)
        XCTAssertNil(workout.notes, "edits in the scratch context must not leak")
        let freshContext = ModelContext(container)
        let refetchedWorkout = try XCTUnwrap(try freshContext.fetch(FetchDescriptor<Workout>()).first)
        XCTAssertNil(refetchedWorkout.notes)
    }

    func testSavePersistsNote() throws {
        let container = try makeContainer()
        let context = makeContext(container)
        let workout = try insertRide(into: context)
        let editing = try NoteEditing.editing(workout, container: container)
        editing.notesText = "  Felt strong on the climb  "
        try editing.save()

        let freshContext = ModelContext(container)
        let refetchedWorkout = try XCTUnwrap(try freshContext.fetch(FetchDescriptor<Workout>()).first)
        XCTAssertEqual(refetchedWorkout.notes, "Felt strong on the climb")
    }

    func testCancelDoesNotPersistNote() throws {
        let container = try makeContainer()
        let context = makeContext(container)
        let workout = try insertRide(into: context)
        do {
            let editing = try NoteEditing.editing(workout, container: container)
            editing.notesText = "Should not be saved"
            XCTAssertNil(workout.notes, "edits in the scratch context must not leak")
        }
        // Session (and its unsaved scratch context) dropped, as Cancel does.

        XCTAssertNil(workout.notes)
        let freshContext = ModelContext(container)
        let refetchedWorkout = try XCTUnwrap(try freshContext.fetch(FetchDescriptor<Workout>()).first)
        XCTAssertNil(refetchedWorkout.notes)
    }

    func testCanSaveRequiresNonEmptyNote() throws {
        let container = try makeContainer()
        let context = makeContext(container)
        let workout = try insertRide(into: context)
        let editing = try NoteEditing.editing(workout, container: container)

        XCTAssertFalse(editing.canSave)
        editing.notesText = "   "
        XCTAssertFalse(editing.canSave)
        editing.notesText = "Good ride"
        XCTAssertTrue(editing.canSave)
    }
}
