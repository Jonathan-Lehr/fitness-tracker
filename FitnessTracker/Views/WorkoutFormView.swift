import SwiftUI
import SwiftData

struct WorkoutFormView: View {
    let workout: Workout?   // nil = add new
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    TextField("iFit program title", text: $title)
                    if !programs.isEmpty {
                        Menu("Choose existing program") {
                            ForEach(programs) { p in Button(p.title) { title = p.title } }
                        }
                    }
                    DatePicker("Start", selection: $date)
                }
                Section("Stats") {
                    numberField("Duration (min)", value: $minutes)
                    numberField("Distance (mi)", value: $miles)
                    intField("Calories", value: $calories)
                    intField("Elevation (ft)", value: $feet)
                    intField("Avg RPM", value: $rpm)
                    intField("Avg Watts", value: $watts)
                    numberField("Incline avg %", value: $incAvg)
                    numberField("Incline max %", value: $incMax)
                    intField("Resistance avg", value: $resAvg)
                    intField("Resistance max", value: $resMax)
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                }
                Section {
                    // TODO: Vision photo import — pick/capture a photo of the s22i summary screen,
                    // run VNRecognizeTextRequest, parse values into the fields above, and store
                    // the image in Workout.photoData. Not implemented yet.
                    Button("Import from Photo (coming soon)") {}.disabled(true)
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

    private func numberField(_ label: String, value: Binding<Double>) -> some View {
        LabeledContent(label) {
            TextField(label, value: value, format: .number)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
        }
    }

    private func intField(_ label: String, value: Binding<Int>) -> some View {
        LabeledContent(label) {
            TextField(label, value: value, format: .number)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
        }
    }

    private func load() {
        guard let w = workout else { return }
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
        try? context.save()
    }
}
