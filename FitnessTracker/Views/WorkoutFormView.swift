import SwiftUI
import SwiftData

struct WorkoutFormView: View {
    let workout: Workout?   // nil = add new
    /// Values parsed from a photo; fields the parser missed are flagged.
    var draft: IFitSummary? = nil
    var draftPhoto: Data? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Program.title) private var programs: [Program]

    @State private var title = ""
    @State private var date = Date.now
    @State private var minutes = 45.0
    @State private var miles = 10.0
    @State private var calories = 350
    @State private var feet = 1000
    @State private var rpm = 75
    @State private var watts = 85
    @State private var incAvg = 2.0
    @State private var incMax = 10.0
    @State private var resAvg = 10
    @State private var resMax = 15
    @State private var notes = ""
    @State private var photoData: Data?

    private var missing: Set<IFitSummary.Field> { draft?.missingFields ?? [] }

    var body: some View {
        NavigationStack {
            Form {
                if draft != nil && !missing.isEmpty {
                    Section {
                        Label("\(missing.count) field\(missing.count == 1 ? "" : "s") couldn't be read from the photo. Check the flagged values.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                Section("Workout") {
                    TextField("iFit program title", text: $title)
                        .overlay(alignment: .trailing) { flag(.title) }
                    if !programs.isEmpty {
                        Menu("Choose existing program") {
                            ForEach(programs) { p in Button(p.title) { title = p.title } }
                        }
                    }
                    DatePicker(selection: $date) { flaggedLabel("Start", .date) }
                }
                Section("Stats") {
                    numberField("Duration (min)", value: $minutes, field: .duration)
                    numberField("Distance (mi)", value: $miles, field: .distance)
                    intField("Calories", value: $calories, field: .calories)
                    intField("Elevation (ft)", value: $feet, field: .elevation)
                    intField("Avg RPM", value: $rpm, field: .rpm)
                    intField("Avg Watts", value: $watts, field: .watts)
                    numberField("Incline avg %", value: $incAvg, field: .inclineAvg)
                    numberField("Incline max %", value: $incMax, field: .inclineMax)
                    intField("Resistance avg", value: $resAvg, field: .resistanceAvg)
                    intField("Resistance max", value: $resMax, field: .resistanceMax)
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                }
                if let photoData, let image = ImageTools.cgImage(from: photoData, maxPixel: 800) {
                    Section("Photo") {
                        Image(decorative: image, scale: 1)
                            .resizable().scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Button("Remove Photo", role: .destructive) { self.photoData = nil }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(workout == nil ? "Add Ride" : "Edit Ride")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 600)
        #endif
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
        if let d = draft {
            title = d.title ?? ""; date = d.date ?? .now
            minutes = d.durationMinutes ?? 0; miles = d.distanceMiles ?? 0
            calories = d.calories ?? 0; feet = d.elevationFeet ?? 0
            rpm = d.avgRPM ?? 0; watts = d.avgWatts ?? 0
            incAvg = d.inclineAvg ?? 0; incMax = d.inclineMax ?? 0
            resAvg = d.resistanceAvg ?? 0; resMax = d.resistanceMax ?? 0
            photoData = draftPhoto
        }
        guard let w = workout else { return }
        photoData = w.photoData
        title = w.title; date = w.date; minutes = w.durationMinutes; miles = w.distanceMiles
        calories = w.calories; feet = w.elevationFeet; rpm = w.avgRPM; watts = w.avgWatts
        incAvg = w.inclineAvg; incMax = w.inclineMax; resAvg = w.resistanceAvg; resMax = w.resistanceMax
        notes = w.notes ?? ""
    }

    private func save() {
        let program = Program.findOrCreate(title: title, in: context)
        let w = workout ?? {
            let new = Workout(date: date, program: program, durationMinutes: 0, distanceMiles: 0, calories: 0,
                              elevationFeet: 0, avgRPM: 0, avgWatts: 0, inclineAvg: 0, inclineMax: 0,
                              resistanceAvg: 0, resistanceMax: 0)
            context.insert(new)
            return new
        }()
        w.program = program; w.date = date; w.durationMinutes = minutes; w.distanceMiles = miles
        w.calories = calories; w.elevationFeet = feet; w.avgRPM = rpm; w.avgWatts = watts
        w.inclineAvg = incAvg; w.inclineMax = incMax; w.resistanceAvg = resAvg; w.resistanceMax = resMax
        w.notes = notes.isEmpty ? nil : notes
        w.photoData = photoData
        try? context.save()
    }
}
