import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    @State private var showEdit = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Program", value: workout.title)
                LabeledContent("Type", value: workout.type.label)
                LabeledContent("Date", value: workout.date.formatted(date: .long, time: .shortened))
            }
            Section("Stats") {
                LabeledContent("Duration", value: workout.durationMinutes.minutesText)
                LabeledContent("Distance", value: workout.distanceMiles.milesText)
                LabeledContent("Calories", value: "\(workout.calories)")
                LabeledContent("Elevation", value: "\(workout.elevationFeet) ft")
                LabeledContent("Avg RPM", value: "\(workout.avgRPM)")
                LabeledContent("Avg Watts", value: "\(workout.avgWatts)")
                LabeledContent("Incline avg / max", value: String(format: "%.1f%% / %.1f%%", workout.inclineAvg, workout.inclineMax))
                LabeledContent("Resistance avg / max", value: "\(workout.resistanceAvg) / \(workout.resistanceMax)")
            }
            if let notes = workout.notes, !notes.isEmpty {
                Section("Notes") { Text(notes) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(workout.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Edit") { showEdit = true } }
        }
        .sheet(isPresented: $showEdit) { WorkoutFormView(workout: workout) }
    }
}
