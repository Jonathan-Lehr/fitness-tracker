import SwiftUI

struct WorkoutRow: View {
    let workout: Workout
    /// The Log's section headers already show the year, so rows omit it by default.
    var showYear = false

    private var dateText: String {
        let base = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()
        return workout.date.formatted(showYear ? base.year() : base)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.title).font(.body.weight(.semibold))
                Spacer()
                Text("\(workout.avgWatts.formattedWholeNumber()) W").monospacedDigit().foregroundStyle(.orange)
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
