import Foundation
import Observation
import SwiftData
import SwiftUI

/// Add/edit-notes session for `NoteEditView`. Edits a copy of the workout in a scratch
/// `ModelContext` on the same container with autosave disabled, matching
/// `WorkoutFormEditing`: Save persists, Cancel just dismisses.
///
/// Presenters create the session and pass it in; see `WorkoutFormView`.
@MainActor @Observable
final class NoteEditing {
    /// Text shown in the sheet. Written to the workout only on Save, after trimming.
    var notesText: String
    /// True when the session opened on a workout that already had a note.
    let isEditingExistingNote: Bool
    private let workout: Workout
    private let context: ModelContext

    static func editing(_ workout: Workout, container: ModelContainer) throws -> NoteEditing {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let identifier = workout.persistentModelID
        // Fetch in the scratch context rather than passing the caller's instance across contexts.
        // `model(for:)` can return an empty stub if the identifier is unknown, so match on ID.
        let scratchWorkout = try context.fetch(FetchDescriptor<Workout>()).first { $0.persistentModelID == identifier }
        guard let scratchWorkout else { throw NoteEditingError.workoutNotFound }
        return NoteEditing(workout: scratchWorkout, context: context)
    }

    private init(workout: Workout, context: ModelContext) {
        self.workout = workout
        self.context = context
        self.notesText = workout.notes ?? ""
        let existingNote = workout.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.isEditingExistingNote = !existingNote.isEmpty
    }

    var navigationTitle: String {
        isEditingExistingNote ? "Edit Notes" : "Add Notes"
    }

    /// Adding requires a non-empty note. Editing always allows Save, including clearing the note.
    var canSave: Bool {
        isEditingExistingNote || !trimmedNote.isEmpty
    }

    /// Persists the trimmed note in the scratch context. An empty value is stored as `nil`.
    /// Nothing is written to the store until this is called.
    func save() throws {
        workout.notes = trimmedNote.isEmpty ? nil : trimmedNote
        try context.save()
    }

    private var trimmedNote: String {
        notesText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension NoteEditing: Identifiable {
    // Identifiable.id is nonisolated; ObjectIdentifier(self) needs no isolated state.
    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }
}

enum NoteEditingError: Error {
    case workoutNotFound
}

/// Small sheet for adding or editing a workout's notes.
struct NoteEditView: View {
    @Bindable var editing: NoteEditing
    @Environment(\.dismiss) private var dismiss
    @FocusState private var notesFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Notes", text: $editing.notesText, axis: .vertical)
                        .focused($notesFocused)
                }
            }
            .formStyle(.grouped)
            #if os(macOS)
            .defaultFocus($notesFocused, true)
            #else
            .onAppear { notesFocused = true }
            #endif
            .navigationTitle(editing.navigationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!editing.canSave)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium])
        #elseif os(macOS)
        .frame(minWidth: 360, minHeight: 240)
        #endif
    }

    private func cancel() {
        dismiss()
    }

    private func save() {
        do {
            try editing.save()
            dismiss()
        } catch {
            // Leave the sheet open so unsaved edits can be retried or cancelled.
        }
    }
}
