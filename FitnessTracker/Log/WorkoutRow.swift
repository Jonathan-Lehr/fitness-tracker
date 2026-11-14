import SwiftUI
import SwiftData

struct WorkoutRow: View {
    let workout: Workout
    /// The Log's section headers already show the year, so rows omit it by default.
    var showYear = false

    private var dateText: String {
        let base = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()
        return workout.date.formatted(showYear ? base.year() : base)
    }

    /// "—" for a workout with no watts, matching the expanded cards and the detail view.
    private var wattsText: String {
        formattedAverageWatts(workout.avgWatts > 0 ? Double(workout.avgWatts) : nil, placeholder: "—")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.title).font(.body.weight(.semibold))
                Spacer()
                Text(wattsText).monospacedDigit().foregroundStyle(.orange)
            }
            HStack(spacing: 12) {
                Text(dateText)
                Text(workout.durationMinutes.formattedMinutes())
                Text(workout.distanceMiles.formattedMilesWithUnit())
                Text("\(workout.calories.formattedWholeNumber()) cal")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
    }
}

#Preview("Workout row") {
    let container = PreviewSupport.container()
    let workout = PreviewSupport.sampleWorkout(in: container)
    List {
        WorkoutRow(workout: workout)
    }
    .modelContainer(container)
}
