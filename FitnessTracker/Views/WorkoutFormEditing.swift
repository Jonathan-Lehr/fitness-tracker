import Foundation
import Observation
import SwiftData

/// Add/edit session for `WorkoutFormView`. The form binds to a real `Workout` so the field
/// list isn't duplicated in a draft type.
///
/// New rides use an uninserted `Workout` (manual defaults or a parser summary). It is inserted
/// into the caller's context only on Save.
///
/// Existing rides are fetched into a scratch `ModelContext` on the same container with
/// autosave disabled, so unsaved edits stay off other views. Save persists; Cancel rolls back.
@MainActor @Observable
final class WorkoutFormEditing {
    /// Program title typed in the form. Applied with `Program.findOrCreate` on Save, not by
    /// renaming the current program (which would rename it for every ride).
    var title: String
    let workout: Workout
    /// Nil when adding a new ride (the workout is not in any context yet).
    private let scratchContext: ModelContext?

    var isEditingExisting: Bool { scratchContext != nil }

    static func manualEntry(date: Date = .now) -> WorkoutFormEditing {
        WorkoutFormEditing(
            workout: Workout(forManualEntry: date),
            title: "",
            scratchContext: nil
        )
    }

    static func prefilled(summary: IFitSummary, photo: Data? = nil,
                          analysis: ThumbnailFocusAnalysis? = nil) -> WorkoutFormEditing {
        let workout = Workout(summary: summary)
        if photo != nil || analysis != nil {
            workout.replacePhoto(with: photo, analysis: analysis)
        }
        return WorkoutFormEditing(
            workout: workout,
            title: summary.title ?? "",
            scratchContext: nil
        )
    }

    static func editing(_ workout: Workout, container: ModelContainer) throws -> WorkoutFormEditing {
        let scratch = ModelContext(container)
        scratch.autosaveEnabled = false
        let identifier = workout.persistentModelID
        // Fetch in the scratch context rather than passing the caller's instance across contexts.
        // `model(for:)` can return an empty stub if the identifier is unknown, so match on ID.
        let copy = try scratch.fetch(FetchDescriptor<Workout>()).first { $0.persistentModelID == identifier }
        guard let copy else { throw WorkoutFormEditingError.workoutNotFound }
        return WorkoutFormEditing(
            workout: copy,
            title: copy.title,
            scratchContext: scratch
        )
    }

    private init(workout: Workout, title: String, scratchContext: ModelContext?) {
        self.workout = workout
        self.title = title
        self.scratchContext = scratchContext
    }

    /// Persists the ride. New rides are inserted into `context` here, not before.
    func save(into context: ModelContext) throws {
        if let scratchContext {
            let program = Program.findOrCreate(title: title, in: scratchContext)
            workout.program = program
            try scratchContext.save()
        } else {
            let program = Program.findOrCreate(title: title, in: context)
            workout.program = program
            context.insert(workout)
            try context.save()
        }
    }

    /// Discards unsaved edits in the scratch context. No-op for a new uninserted ride.
    func cancel() {
        scratchContext?.rollback()
    }
}

enum WorkoutFormEditingError: Error {
    case workoutNotFound
}
