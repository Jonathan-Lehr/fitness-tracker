import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let workout: Workout
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                WorkoutSummaryCard(workout: workout)
                    .padding(.horizontal)

                if let notes = workout.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 20)
                        Text(notes)
                            .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle(workout.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            WorkoutFormView(workout: workout)
        }
    }
}

/// Single-workout summary card. TypeTag now sits alongside the date (in its original location below the photo, no overlay). 
/// Prominent Miles/Watts, full-width leading-aligned tiles, consistent edges, no border. Matches all feedback.
struct WorkoutSummaryCard: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Hero image (no overlay). TypeTag moved to HStack with date in its original location.
            RideImage(workout: workout, aspect: 16.0 / 9.0)
                .frame(maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                    .font(.title2.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                HStack {
                    Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                    TypeTag(type: workout.type)
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 4)

            // Prominent distance + watts (title for "12.5 Miles", title2 for "105 Watts")
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.distanceMiles.milesString)
                    .font(.title.bold())
                    .monospacedDigit()
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                Text(workout.avgWatts > 0 ? "\(workout.avgWatts) Watts" : "— Watts")
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)

            // Secondary stats (equal flexible columns to fill container width, leading-aligned)
            HStack(alignment: .top, spacing: 0) {
                StatTile(
                    value: workout.durationMinutes.minutesText,
                    label: "Duration",
                    numericValue: workout.durationMinutes
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
                StatTile(
                    value: "\(workout.calories)",
                    label: "Calories",
                    numericValue: Double(workout.calories)
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
                StatTile(
                    value: "\(workout.elevationFeet) ft",
                    label: "Elevation",
                    numericValue: Double(workout.elevationFeet)
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
                StatTile(
                    value: workout.avgRPM > 0 ? "\(workout.avgRPM)" : "—",
                    label: "RPM",
                    numericValue: Double(workout.avgRPM)
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 4)

            // Additional stats (incline, resistance) — leading edge aligned with content above
            VStack(alignment: .leading, spacing: 8) {
                Text("Additional Stats")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.1f%% / %.1f%%", workout.inclineAvg, workout.inclineMax))
                            .font(.headline.weight(.semibold))
                        Text("Incline avg / max")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(workout.resistanceAvg) / \(workout.resistanceMax)")
                            .font(.headline.weight(.semibold))
                        Text("Resistance avg / max")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(20)
        .background(LogSurface.card, in: RoundedRectangle(cornerRadius: 20))
    }
}
