import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let workout: Workout
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary card with photo, type tag, prominent distance and watts, and stats.
                // Matches the design settled in issue #11: one adaptive card for iPhone and Mac.
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

/// Single-workout summary card. Reuses StatTile (extracted from PeriodSummaryCard), RideImage,
/// TypeTag, and LogSurface from RideGridView. Prominent metrics: distance (hero) and avg Watts.
/// Secondary: duration, calories, elevation, RPM. Incline and resistance in "Additional Stats".
struct WorkoutSummaryCard: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Hero image with type tag (reused from grid)
            ZStack(alignment: .topLeading) {
                RideImage(workout: workout, aspect: 16.0 / 9.0)
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                TypeTag(type: workout.type)
                    .padding(12)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                    .font(.title2.bold())

                Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            // Prominent metrics row
            HStack(spacing: 20) {
                StatTile(
                    value: workout.distanceMiles.milesText,
                    label: "Distance",
                    numericValue: workout.distanceMiles
                )

                StatTile(
                    value: workout.avgWatts > 0 ? "\(workout.avgWatts) W" : "—",
                    label: "Avg Watts",
                    numericValue: Double(workout.avgWatts)
                )
            }
            .padding(.horizontal, 4)

            // Secondary stats
            HStack(spacing: 16) {
                StatTile(
                    value: workout.durationMinutes.minutesText,
                    label: "Duration",
                    numericValue: workout.durationMinutes
                )
                StatTile(
                    value: "\(workout.calories)",
                    label: "Calories",
                    numericValue: Double(workout.calories)
                )
                StatTile(
                    value: "\(workout.elevationFeet) ft",
                    label: "Elevation",
                    numericValue: Double(workout.elevationFeet)
                )
                StatTile(
                    value: workout.avgRPM > 0 ? "\(workout.avgRPM)" : "—",
                    label: "RPM",
                    numericValue: Double(workout.avgRPM)
                )
            }
            .padding(.horizontal, 4)

            // Additional stats (incline, resistance) — matches settled design
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
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.separator, lineWidth: 1)
        )
    }
}
