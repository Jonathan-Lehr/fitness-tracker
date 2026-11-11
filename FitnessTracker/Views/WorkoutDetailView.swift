import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                WorkoutSummaryCard(workout: workout)
                    .padding(.horizontal)

                notesSection
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

    @ViewBuilder private var notesSection: some View {
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
}

/// Summary card for a single workout: photo, title, date and type, then distance and average
/// Watts featured above the secondary stats. Stats use the shared `StatTile` so they match the
/// period summary cards; no deltas until baseline comparison lands (#28).
struct WorkoutSummaryCard: View {
    let workout: Workout

    /// Secondary stats share one row in equal flexible columns; tile text scales down to fit.
    private let secondaryColumns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .leading), count: 4)
    /// Additional stats use two equal columns.
    private let additionalColumns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .leading), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            photo
            heading
                .padding(.horizontal, 4)
            featuredStats
                .padding(.horizontal, 4)
            statGrid(secondaryStats, columns: secondaryColumns)
                .padding(.horizontal, 4)
            additionalStats
                .padding(.horizontal, 4)
        }
        .padding(20)
        .background(LogSurface.card, in: RoundedRectangle(cornerRadius: 20))
    }

    private var photo: some View {
        RideImage(workout: workout, aspect: 16.0 / 9.0)
            .frame(maxHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var heading: some View {
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
                TypeTag(type: workout.type, contentAlignment: .center)
            }
            .padding(.vertical, 8)
        }
    }

    private var featuredStats: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(workout.distanceMiles.milesString)
                    .font(.title.bold())
                    .monospacedDigit()
                Text("Miles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)

            Text(workout.avgWatts > 0 ? "\(workout.avgWatts) Watts" : "— Watts")
                .font(.title2.bold())
                .monospacedDigit()
                .foregroundStyle(.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var secondaryStats: [StatTile] {
        [
            StatTile(value: workout.durationMinutes.minutesText, label: "Duration",
                     numericValue: workout.durationMinutes),
            StatTile(value: "\(workout.calories)", label: "Calories",
                     numericValue: Double(workout.calories)),
            StatTile(value: "\(workout.elevationFeet) ft", label: "Elevation",
                     numericValue: Double(workout.elevationFeet)),
            StatTile(value: workout.avgRPM > 0 ? "\(workout.avgRPM)" : "—", label: "RPM",
                     numericValue: Double(workout.avgRPM)),
        ]
    }

    private var additionalStats: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Additional Stats")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            statGrid(additionalStatTiles, columns: additionalColumns)
        }
    }

    private var additionalStatTiles: [StatTile] {
        [
            StatTile(value: String(format: "%.1f%% / %.1f%%", workout.inclineAvg, workout.inclineMax),
                     label: "Incline avg / max"),
            StatTile(value: "\(workout.resistanceAvg) / \(workout.resistanceMax)",
                     label: "Resistance avg / max"),
        ]
    }

    private func statGrid(_ tiles: [StatTile], columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(tiles.indices, id: \.self) { index in
                tiles[index]
            }
        }
    }
}
