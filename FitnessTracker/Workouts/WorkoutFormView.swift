import SwiftUI
import SwiftData

struct WorkoutFormView: View {
    /// Created by the presenter and passed in, so the form can render immediately.
    /// The session needs the model container to build its scratch context, and
    /// `@Environment` isn't available in `View.init`, so creating it here would
    /// mean waiting until `onAppear` and showing a `ProgressView` in the meantime.
    @Bindable var editing: WorkoutFormEditing
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Program.title) private var programs: [Program]

    var body: some View {
        NavigationStack {
            WorkoutFormEditor(
                editing: editing,
                workout: editing.workout,
                programs: programs,
                missing: editing.missingFields,
                onCancel: cancel,
                onSave: save
            )
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 600)
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
            // Leave the form open so unsaved edits can be retried or cancelled.
        }
    }
}

/// Binds the form to the session's `Workout` (and the program title, which is not a workout field).
private struct WorkoutFormEditor: View {
    @Bindable var editing: WorkoutFormEditing
    @Bindable var workout: Workout
    let programs: [Program]
    let missing: Set<IFitSummary.Field>
    let onCancel: () -> Void
    let onSave: () -> Void

    private var notesBinding: Binding<String> {
        Binding(
            get: { workout.notes ?? "" },
            set: { workout.notes = $0.isEmpty ? nil : $0 }
        )
    }

    var body: some View {
        Form {
            if !missing.isEmpty {
                Section {
                    missingFieldsBanner
                }
            }
            Section("Workout") {
                workoutFields
            }
            Section("Stats") {
                statsFields
            }
            Section("Notes") {
                TextField("Notes", text: notesBinding, axis: .vertical)
            }
            if let photoData = workout.photoData,
               let image = ImageTools.cgImage(from: photoData, maxPixel: 800) {
                Section("Photo") {
                    photoFields(image: image)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(editing.isEditingExisting ? "Edit Ride" : "Add Ride")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: onSave)
                    .disabled(Program.normalizedTitle(editing.title).isEmpty)
            }
        }
    }

    private var missingFieldsBanner: some View {
        Label("^[\(missing.count) field](inflect: true) couldn't be read from the photo. Check the flagged values.",
              systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
    }

    @ViewBuilder
    private var workoutFields: some View {
        TextField("iFit program title", text: $editing.title)
            .overlay(alignment: .trailing) { flag(.title) }
        if !programs.isEmpty {
            Menu("Choose existing program") {
                ForEach(programs) { program in
                    Button(program.title) { editing.title = program.title }
                }
            }
        }
        DatePicker(selection: $workout.date) { flaggedLabel("Start", .date) }
    }

    @ViewBuilder
    private var statsFields: some View {
        numberField("Duration (min)", value: $workout.durationMinutes, field: .duration)
        numberField("Distance (mi)", value: $workout.distanceMiles, field: .distance)
        intField("Calories", value: $workout.calories, field: .calories)
        intField("Elevation (ft)", value: $workout.elevationFeet, field: .elevation)
        intField("Avg RPM", value: $workout.avgRPM, field: .rpm)
        intField("Avg Watts", value: $workout.avgWatts, field: .watts)
        numberField("Incline avg %", value: $workout.inclineAvg, field: .inclineAvg)
        numberField("Incline max %", value: $workout.inclineMax, field: .inclineMax)
        intField("Resistance avg", value: $workout.resistanceAvg, field: .resistanceAvg)
        intField("Resistance max", value: $workout.resistanceMax, field: .resistanceMax)
    }

    @ViewBuilder
    private func photoFields(image: CGImage) -> some View {
        Image(decorative: image, scale: 1)
            .resizable().scaledToFit()
            .frame(maxHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        Button("Remove Photo", role: .destructive) {
            workout.replacePhoto(with: nil)
        }
    }

    @ViewBuilder
    private func flag(_ field: IFitSummary.Field) -> some View {
        if missing.contains(field) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .help("Not found in photo")
                .accessibilityLabel("Not found in photo")
        }
    }

    private func flaggedLabel(_ label: String, _ field: IFitSummary.Field) -> some View {
        HStack(spacing: 4) {
            Text(label)
            flag(field)
        }
        .foregroundStyle(missing.contains(field) ? Color.orange : Color.primary)
    }

    private func numberField(_ label: String, value: Binding<Double>, field: IFitSummary.Field) -> some View {
        LabeledContent {
            TextField(label, value: value, format: .number)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
        } label: { flaggedLabel(label, field) }
    }

    private func intField(_ label: String, value: Binding<Int>, field: IFitSummary.Field) -> some View {
        LabeledContent {
            TextField(label, value: value, format: .number)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
        } label: { flaggedLabel(label, field) }
    }
}
