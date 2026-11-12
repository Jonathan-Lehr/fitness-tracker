import Foundation
import Observation
import SwiftData

/// Add/edit session for `WorkoutFormView`. The form binds to a real `Workout` so the field
/// list isn't duplicated in a draft type.
///
/// Every session uses a scratch `ModelContext` on the same container with autosave disabled,
/// so unsaved edits stay off other views. New rides (manual defaults or a parser summary) are
/// inserted into that context when the session is created; existing rides are fetched into it.
/// Save persists. Cancel just dismisses; dropping the unsaved scratch context discards the edits.
///
/// Presenters create the session (the form cannot, because `@Environment` is unavailable in
/// `View.init`); see `WorkoutFormView`.
@MainActor @Observable
final class WorkoutFormEditing {
    /// Program title typed in the form. Applied with `Program.findOrCreate` on Save, not by
    /// renaming the current program (which would rename it for every ride).
    var title: String
    let workout: Workout
    /// True when this session is editing a ride that already exists in the store.
    let isEditingExisting: Bool
    /// Fields the parser missed, flagged in the form. Empty for manual entry and edits.
    let missingFields: Set<IFitSummary.Field>
    private let context: ModelContext

    static func manualEntry(date: Date = .now, container: ModelContainer) -> WorkoutFormEditing {
        let context = makeContext(container)
        let workout = Workout(forManualEntry: date)
        context.insert(workout)
        return WorkoutFormEditing(
            workout: workout,
            title: "",
            isEditingExisting: false,
            missingFields: [],
            context: context
        )
    }

    static func prefilled(summary: IFitSummary, photo: Data? = nil,
                          analysis: ThumbnailFocusAnalysis? = nil,
                          container: ModelContainer) -> WorkoutFormEditing {
        let context = makeContext(container)
        let workout = Workout(summary: summary)
        if photo != nil || analysis != nil {
            workout.replacePhoto(with: photo, analysis: analysis)
        }
        context.insert(workout)
        return WorkoutFormEditing(
            workout: workout,
            title: summary.title ?? "",
            isEditingExisting: false,
            missingFields: summary.missingFields,
            context: context
        )
    }

    static func editing(_ workout: Workout, container: ModelContainer) throws -> WorkoutFormEditing {
        let context = makeContext(container)
        let identifier = workout.persistentModelID
        // Fetch in the scratch context rather than passing the caller's instance across contexts.
        // `model(for:)` can return an empty stub if the identifier is unknown, so match on ID.
        let scratchWorkout = try context.fetch(FetchDescriptor<Workout>()).first { $0.persistentModelID == identifier }
        guard let scratchWorkout else { throw WorkoutFormEditingError.workoutNotFound }
        return WorkoutFormEditing(
            workout: scratchWorkout,
            title: scratchWorkout.title,
            isEditingExisting: true,
            missingFields: [],
            context: context
        )
    }

    private init(workout: Workout, title: String, isEditingExisting: Bool,
                 missingFields: Set<IFitSummary.Field>, context: ModelContext) {
        self.workout = workout
        self.title = title
        self.isEditingExisting = isEditingExisting
        self.missingFields = missingFields
        self.context = context
    }

    private static func makeContext(_ container: ModelContainer) -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    /// Persists the ride in the scratch context. Nothing is written to the store until this is called.
    func save() throws {
        let program = Program.findOrCreate(title: title, in: context)
        workout.program = program
        try context.save()
    }
}

extension WorkoutFormEditing: Identifiable {
    var id: ObjectIdentifier { ObjectIdentifier(self) }
}

enum WorkoutFormEditingError: Error {
    case workoutNotFound
}
