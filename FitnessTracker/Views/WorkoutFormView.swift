import SwiftUI
import SwiftData

struct WorkoutFormView: View {
    let workout: Workout?   // nil = add new
    /// Values parsed from a photo; fields the parser missed are flagged.
    var draft: IFitSummary? = nil
    var draftPhoto: Data? = nil
    /// Thumbnail framing computed for `draftPhoto` during import.
    var draftThumbnailAnalysis: ThumbnailFocusAnalysis? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Program.title) private var programs: [Program]

    @State private var workoutDraft = WorkoutDraft.manualEntry

    private var missing: Set<IFitSummary.Field> { draft?.missingFields ?? [] }

    var body: some View {
        NavigationStack {
            Form {
                if draft != nil && !missing.isEmpty {
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
                    TextField("Notes", text: $workoutDraft.notes, axis: .vertical)
                }
                if let photoData = workoutDraft.photoData, let image = ImageTools.cgImage(from: photoData, maxPixel: 800) {
                    Section("Photo") {
                        photoFields(image: image)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(workout == nil ? "Add Ride" : "Edit Ride")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                        .disabled(Program.normalizedTitle(workoutDraft.title).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 600)
        #endif
    }

    private var missingFieldsBanner: some View {
        Label("\(missing.count) field\(missing.count == 1 ? "" : "s") couldn't be read from the photo. Check the flagged values.",
              systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
    }

    @ViewBuilder
    private var workoutFields: some View {
        TextField("iFit program title", text: $workoutDraft.title)
            .overlay(alignment: .trailing) { flag(.title) }
        if !programs.isEmpty {
            Menu("Choose existing program") {
                ForEach(programs) { program in Button(program.title) { workoutDraft.title = program.title } }
            }
        }
        DatePicker(selection: $workoutDraft.date) { flaggedLabel("Start", .date) }
    }

    @ViewBuilder
    private var statsFields: some View {
        numberField("Duration (min)", value: $workoutDraft.durationMinutes, field: .duration)
        numberField("Distance (mi)", value: $workoutDraft.distanceMiles, field: .distance)
        intField("Calories", value: $workoutDraft.calories, field: .calories)
        intField("Elevation (ft)", value: $workoutDraft.elevationFeet, field: .elevation)
        intField("Avg RPM", value: $workoutDraft.avgRPM, field: .rpm)
        intField("Avg Watts", value: $workoutDraft.avgWatts, field: .watts)
        numberField("Incline avg %", value: $workoutDraft.inclineAvg, field: .inclineAvg)
        numberField("Incline max %", value: $workoutDraft.inclineMax, field: .inclineMax)
        intField("Resistance avg", value: $workoutDraft.resistanceAvg, field: .resistanceAvg)
        intField("Resistance max", value: $workoutDraft.resistanceMax, field: .resistanceMax)
    }

    @ViewBuilder
    private func photoFields(image: CGImage) -> some View {
        Image(decorative: image, scale: 1)
            .resizable().scaledToFit()
            .frame(maxHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        Button("Remove Photo", role: .destructive) { workoutDraft.photoData = nil }
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

    private func load() {
        if let summary = draft {
            workoutDraft = WorkoutDraft(summary: summary, photoData: draftPhoto)
        }
        guard let workout else { return }
        workoutDraft = WorkoutDraft(workout: workout)
    }

    private func save() {
        let program = Program.findOrCreate(title: workoutDraft.title, in: context)
        let workout = workout ?? {
            let new = Workout(date: workoutDraft.date, program: program)
            context.insert(new)
            return new
        }()
        workout.program = program
        workoutDraft.apply(to: workout)
        workout.replacePhoto(with: workoutDraft.photoData,
                             analysis: workoutDraft.photoData == draftPhoto ? draftThumbnailAnalysis : nil)
        try? context.save()
    }
}
